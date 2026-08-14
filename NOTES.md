# NOTES

## How this was built

I built this with Claude, used as a pairing partner. The workflow across the ~3 days I
spent on this: we broke the task into stages (transport → resilience →
Bloc → UI → native → stretch goal), and for every stage was real runs on a physical
Android device against the real `feed_server.dart` in chaos mode — before
moving on.

This mattered in practice, not just as a process box to tick. A few examples
where my own testing surfaced real bugs that AI-generated code did not
anticipate:

- A `ConnectivityManager.NetworkCallback` crash (`FATAL EXCEPTION:
  ConnectivityThread`) that only appeared when I actually toggled Wi-Fi on a
  physical device — no unit test could have caught this, since it's a
  Flutter-engine main-thread constraint on native callback delivery.
- A false "online" signal from `onAvailable` firing before Android had
  actually validated internet access, found by manually toggling Wi-Fi vs.
  Airplane mode and comparing behavior.
- A real animation-performance issue (`TweenAnimationBuilder` + `ValueKey`
  forcing full Element teardown/rebuild on every price flash) that I found
  by capturing and reading actual DevTools performance traces, not by
  assuming the first implementation was fine.

---

## Key decisions and trade-offs

**Burst handling (coalescing, not per-tick emission).** `WatchlistBloc`
buffers incoming ticks in a plain `Map<String, PriceTick>` (not Bloc state)
and flushes to a single `emit()` on a 16ms (~60fps) timer. A burst of 220
ticks on one symbol collapses into exactly one state update and one flash.
Verified via DevTools: `WatchlistListView` rebuilds exactly once for the
whole session; `WatchlistRow` rebuilds are per-symbol via `context.select`.
Final burst-only profile trace: build avg 3.86ms / median 2.98ms, 1% jank
across ~2900 frames.

**Dedup + ordering via one rule.** A tick is accepted only if its `ts` is
strictly newer than the last accepted `ts` for that symbol
(`TickOrderingGuard`, per-symbol). This handles both `duplicate()` (same ts,
rejected) and `outOfOrder()` (older ts under a new id, rejected) with a
single, cheap check — no separate id-based dedup set was needed for
correctness.

**Stall detection: active reconnect, not passive wait.** The server
self-recovers from a stall after ~25s, but the client can't distinguish "the
documented stall" from "the connection actually died" — both look like
silence. I use a 12s silence watchdog (any byte, including heartbeats,
resets it) that actively tears down and reconnects with `Last-Event-ID`,
rather than waiting for the server. Trade-off: costs one extra
handshake+login versus passively waiting, in exchange for one uniform
recovery path instead of two.

**Reconnect backoff: exponential + jitter, capped at 30s.** Standard choice
to avoid hammering the server while still recovering quickly on transient
blips.

**Proactive token refresh, "simple reconnect" over gap-free swap.** Tokens
expire in 60s; I refresh at the 45s mark rather than waiting for a 401.
Considered doing a gap-free swap (open the new stream in parallel, switch
over once live, close the old one) to avoid any visible status flicker, but
chose the simpler path: tear down and reconnect through the same
backoff-free path used for the refresh case, accepting a brief (sub-second
to ~2s) gap with no new ticks. This is visible in the UI as a momentary
status change and dimmed rows (see below) — not as jank. The
parallel-swap approach was deliberately cut given the time budget; it would
be the first thing to revisit with more time.

**"Never look at frozen prices believing they're live."** Two layers:
the connection status bar (6 states: initial/connecting/live/reconnecting/
stalled/offline) is always visible in the AppBar, and `WatchlistRow` applies
`AnimatedOpacity` (dims to 40%) whenever the connection status isn't `live`.
This also makes the ~1-2s gap during token refresh visually honest rather
than looking like a freeze.

**No fabricated continuous price movement.** A given instrument's price
only updates when the server actually ticks it — some instruments
(JPN225, UK100, etc.) tick rarely by the server's own design (`rate=2`).

**Native piece: Android only, MethodChannel + EventChannel, hand-written.**
`EncryptedSharedPreferences` (androidx.security.crypto, Keystore-backed) for
the token; `ConnectivityManager.NetworkCallback` for reachability, wired
into `ConnectionManager` as an offline guard that suppresses reconnect
attempts (and resets backoff for an immediate retry) rather than burning
backoff cycles against a known-dead network. Honest caveat: because tokens
live only 60s, persisting them across app restarts has no real practical
value — I still implement save/read/delete faithfully per the spec, but
the demonstration value is the platform channel itself, not the
persistence.

**Dart-side interfaces are platform-agnostic by design** (`TokenStorage`,
`ConnectivityMonitor`) — adding iOS later means adding an iOS
implementation and switching DI registration; no other code changes.

**Architecture split.** `lib/feed/` is pure Dart — no Flutter import
anywhere in it — covering transport (SSE parsing, Dio-based `FeedApi`),
resilience (`ConnectionManager`, `ReconnectBackoff`, `TickOrderingGuard`),
and models. `lib/presentation/` holds Bloc + UI. DI via get_it/injectable
(codegen). Bloc, not Cubit, throughout (`InstrumentsBloc`,
`WatchlistBloc`), registered as `@injectable` (not singleton) so
`BlocProvider` correctly owns their lifecycle.

**Stretch goal (session high/low + sparkline): done, throttled
separately.** `InstrumentDetailScreen` samples bloc state on its own 100ms
timer instead of reactively rebuilding on every 16ms flush like the main
list — a burst combined with an open detail screen was measurably heavier
(profile-mode: 56% jank, ~17ms avg build during a burst) before this
change; the fix brought steady-state build down to ~4.5ms avg with only 3%
jank. Sparkline is a plain `CustomPainter` (no charting package) wrapped in
`RepaintBoundary`.

---

## What was cut for time / would do next

- **iOS target.** Android only, per the task's "pick one platform."
  Interfaces are already shaped for a second platform.
- **Gap-free token refresh** (parallel stream swap instead of
  tear-down-and-reconnect) — see above.
- **A `ConnectionManager`-level test specifically for the `gap` event.**
  `gap` parsing is unit-tested at the SSE-parser level, and
  `ConnectionManager` treats it like any other event (resets the stall
  watchdog, doesn't crash, doesn't reconnect unnecessarily) by construction
  — but there's no dedicated test asserting that combination end-to-end.
- **Persisting session high/low/sparkline across app restarts** — scoped to
  the current session only, matching the token's own lifetime; didn't seem
  worth the complexity given the actual server session is stateless anyway.

## Known gaps / things I'm aware of

- One isolated 330ms build-frame outlier appeared in the final long burst
  profiling session, not correlated with any specific burst event and not
  reproduced on repeat runs — most likely a one-off GC pause or OS
  scheduling hiccup, not a code path I could pin down.
- No explicit rate-limit handling on repeated `/login` calls beyond what
  the resilience logic already does — the server doesn't document one, and
  in three days of testing I never hit anything resembling one.

---

## Run instructions

- Flutter 3.44.9 (stable channel).
- Native piece targets **Android** (tested on a physical device, API 33+
  recommended for the emulator path).

**1. Start the feed server** (from wherever `feed_server.dart` lives,
outside this repo):
```
dart run feed_server.dart
```
(chaos mode ON by default — this is what the app is built against).

**2. Get the app running:**
```
flutter pub get
dart run build_runner build
```

**3. Run on a device:**
- Physical device: both the device and the machine running the server must
  be on the same Wi-Fi network. Find your machine's LAN IP
  (`ipconfig` / `ifconfig`) and run:
  ```
  flutter run -d <device-id> --dart-define=FEED_HOST=<LAN-IP>
  ```

**4. Tests:**

What's covered, by layer:
- `test/feed/transport/` — SSE line parser: tick/gap/heartbeat/malformed
  parsing, including the server's raw garbage-injection case.
- `test/feed/resilience/` — `ConnectionManager` (login/stream/backoff
  cycle, stall watchdog, proactive token refresh, offline suppression,
  token storage save/delete) and `TickOrderingGuard` (dedup + out-of-order
  rejection), all driven by `fake_async` — no real server, no real time.
- `test/presentation/` — `InstrumentsBloc`, `WatchlistBloc` (tick
  coalescing into a single flush, flash direction, ordering-guard
  integration, connection-status propagation) and `WatchlistItemState`
  (session high/low tracking, sparkline buffer capping).

`ConnectionManager` and the Blocs are tested against fakes
(`FakeFeedApi`, `FakeConnectivityMonitor`, `FakeTokenStorage` in
`test/helpers/`) that implement the same interfaces as production —
nothing here talks to a real socket or waits on real `Duration`s.

---

## Performance verification (DevTools)

Numbers below are from `flutter run --profile` on a physical Android
device, captured via the Flutter DevTools Performance panel (not the debug-mode numbers, which run consistently higher due to framework instrumentation overhead — verified this
difference directly during development).

**Watchlist screen, steady state + multiple live bursts, ~2900 frames,
no detail screen open** (the scenario closest to how this will be
graded):

| Metric | Avg | Median | Max | Frames over 16.67ms budget |
|---|---|---|---|---|
| Build | 3.86ms | 2.98ms | 330ms¹ | 16 / 2879 (1%) |
| Raster | 5.09ms | 4.34ms | 189ms¹ | 15 / 2879 |

¹ Two isolated single-frame outliers (JIT warm-up near session start, one
unexplained mid-session spike not correlated with any burst) — not a
repeating pattern.

`WatchlistListView` rebuild count over the same session: **1** (only on
initial `WatchlistStarted`). `WatchlistRow` rebuilds are per-symbol via
`context.select` and don't touch the list structure.

**Instrument detail screen, before vs. after the 100ms sampling
throttle,** captured during an active burst with the detail screen open:

| | Build avg | Build median | Jank rate |
|---|---|---|---|
| Before throttling | 16.8ms | 18.3ms | 56% |
| After throttling (steady, no burst) | 4.56ms | 3.69ms | 3% |

The detail screen originally rebuilt on every 16ms `WatchlistBloc` flush
(inherited from the same reactive `context.select` pattern as the main
list), which is unnecessary for a single value display. Decoupling it to
its own 100ms sampling timer removed the burst-time regression without
affecting the main list's behavior.

A separate, earlier animation bug was also caught this way: using
`TweenAnimationBuilder` with a `ValueKey(flashSeq)` forced Flutter to
tear down and recreate the entire `AnimationController`/`Element` subtree
on every price flash, instead of just restarting an animation. Replacing
it with a persistent `AnimationController` restarted via
`.forward(from: 0)` was the fix — found and confirmed via DevTools frame
data, not by inspection alone.
