import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_live_market_watchlist/feed/errors/feed_exceptions.dart';
import 'package:flutter_live_market_watchlist/feed/models/auth_token.dart';
import 'package:flutter_live_market_watchlist/feed/models/connection_status.dart';
import 'package:flutter_live_market_watchlist/feed/models/instrument.dart';
import 'package:flutter_live_market_watchlist/feed/resilience/connection_manager.dart';
import 'package:flutter_live_market_watchlist/feed/transport/feed_api.dart';
import 'package:flutter_live_market_watchlist/feed/transport/sse_event.dart';
import 'package:flutter_live_market_watchlist/feed/models/connection_snapshot.dart';

class FakeFeedApi implements FeedApi {
  int loginCalls = 0;
  Object? nextLoginError;
  final streamControllers = <StreamController<SseEvent>>[];
  final lastEventIdsRequested = <int?>[];

  @override
  Future<AuthToken> login() async {
    loginCalls++;
    final err = nextLoginError;
    if (err != null) {
      nextLoginError = null;
      throw err;
    }
    return const AuthToken(value: 'tok', expiresInSeconds: 60);
  }

  @override
  Future<List<Instrument>> fetchInstruments(String token) async => const [];

  @override
  Stream<SseEvent> openStream({required String token, int? lastEventId}) {
    lastEventIdsRequested.add(lastEventId);
    final controller = StreamController<SseEvent>();
    streamControllers.add(controller);
    return controller.stream;
  }
}

void main() {
  group('ConnectionManager', () {
    test('goes connecting -> live on successful login+stream', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);
        final statuses = <ConnectionStatus>[];
        manager.statusStream.listen((s) => statuses.add(s.status));

        manager.start();
        async.flushMicrotasks();

        expect(statuses, [ConnectionStatus.connecting, ConnectionStatus.live]);
        expect(api.loginCalls, 1);

        manager.dispose();
      });
    });

    test('stream error triggers reconnecting then live after backoff', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);
        final statuses = <ConnectionStatus>[];
        manager.statusStream.listen((s) => statuses.add(s.status));

        manager.start();
        async.flushMicrotasks();
        expect(statuses.last, ConnectionStatus.live);

        api.streamControllers.single.addError(const FeedNetworkException('dropped'));
        async.flushMicrotasks();
        expect(statuses.last, ConnectionStatus.reconnecting);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(statuses.last, ConnectionStatus.live);
        expect(api.loginCalls, 2);

        manager.dispose();
      });
    });

    test('backoff delay grows between consecutive failures', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);

        manager.start();
        async.flushMicrotasks();

        api.streamControllers.last.addError(const FeedNetworkException('x'));
        async.flushMicrotasks();
        final callsAfterFailure = api.loginCalls;

        async.elapse(const Duration(milliseconds: 500));
        expect(api.loginCalls, callsAfterFailure); // too soon, backoff not elapsed

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(api.loginCalls, callsAfterFailure + 1);

        manager.dispose();
      });
    });

    test('stop() cancels a pending reconnect and does not resume', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);

        manager.start();
        async.flushMicrotasks();

        api.streamControllers.single.addError(const FeedNetworkException('x'));
        async.flushMicrotasks();

        manager.stop();
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(api.loginCalls, 1);

        manager.dispose();
      });
    });

    test('reconnect passes Last-Event-ID from the most recent tick', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);

        manager.start();
        async.flushMicrotasks();

        api.streamControllers.single.add(
          SseEvent.tick(id: 42, data: const {'s': 'EURUSD', 'b': 1.0, 'a': 1.0, 'ts': 1}),
        );
        async.flushMicrotasks();

        api.streamControllers.last.addError(const FeedNetworkException('x'));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(api.lastEventIdsRequested, [null, 42]);

        manager.dispose();
      });
    });

    test('login failure also schedules a reconnect', () {
      fakeAsync((async) {
        final api = FakeFeedApi()..nextLoginError = const FeedNetworkException('down');
        final manager = ConnectionManager(api);
        final statuses = <ConnectionStatus>[];
        manager.statusStream.listen((s) => statuses.add(s.status));

        manager.start();
        async.flushMicrotasks();
        expect(statuses.last, ConnectionStatus.reconnecting);
        expect(api.loginCalls, 1);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(statuses.last, ConnectionStatus.live);
        expect(api.loginCalls, 2);

        manager.dispose();
      });
    });

    test('silence longer than stall timeout marks stalled then reconnects', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);
        final statuses = <ConnectionStatus>[];
        manager.statusStream.listen((s) => statuses.add(s.status));

        manager.start();
        async.flushMicrotasks();
        expect(statuses.last, ConnectionStatus.live);

        async.elapse(const Duration(seconds: 12));
        async.flushMicrotasks();

        expect(statuses, containsAllInOrder([
          ConnectionStatus.live,
          ConnectionStatus.stalled,
          ConnectionStatus.reconnecting,
        ]));
        expect(api.loginCalls, 1); // reconnect not yet attempted, still in backoff delay

        manager.dispose();
      });
    });

    test('a tick within the stall window resets the timer and stays live', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);
        final statuses = <ConnectionStatus>[];
        manager.statusStream.listen((s) => statuses.add(s.status));

        manager.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        api.streamControllers.single.add(
          SseEvent.tick(id: 1, data: const {'s': 'EURUSD', 'b': 1.0, 'a': 1.0, 'ts': 1}),
        );
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10)); // total 20s, but timer reset at t=10s
        async.flushMicrotasks();

        expect(statuses, isNot(contains(ConnectionStatus.stalled)));

        manager.dispose();
      });
    });

    test('a heartbeat (no tick data) also resets the stall timer', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);
        final statuses = <ConnectionStatus>[];
        manager.statusStream.listen((s) => statuses.add(s.status));

        manager.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        api.streamControllers.single.add(const SseEvent.heartbeat());
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(statuses, isNot(contains(ConnectionStatus.stalled)));

        manager.dispose();
      });
    });

    test('token is proactively refreshed before it expires, no backoff bump', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);
        final statuses = <ConnectionSnapshot>[];
        manager.statusStream.listen(statuses.add);

        manager.start();
        async.flushMicrotasks();
        expect(api.loginCalls, 1);

        // Simulate the server's ~5s heartbeat cadence so the stall
        // watchdog (12s) doesn't fire while we wait for the refresh at 45s.
        for (var i = 0; i < 9; i++) {
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          if (i < 8) {
            api.streamControllers.last.add(const SseEvent.heartbeat());
            async.flushMicrotasks();
          }
        }

        expect(api.loginCalls, 2);
        expect(statuses.last.status, ConnectionStatus.live);
        expect(statuses.last.reconnectAttempt, 0);

        manager.dispose();
      });
    });

    test('refresh reconnects using the last known event id', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);

        manager.start();
        async.flushMicrotasks();

        api.streamControllers.single.add(
          SseEvent.tick(id: 7, data: const {'s': 'EURUSD', 'b': 1.0, 'a': 1.0, 'ts': 1}),
        );
        async.flushMicrotasks();

        for (var i = 0; i < 9; i++) {
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          if (i < 8) {
            api.streamControllers.last.add(const SseEvent.heartbeat());
            async.flushMicrotasks();
          }
        }

        expect(api.lastEventIdsRequested, [null, 7]);

        manager.dispose();
      });
    });

    test('refresh failure falls back to backoff reconnect', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);
        final statuses = <ConnectionStatus>[];
        manager.statusStream.listen((s) => statuses.add(s.status));

        manager.start();
        async.flushMicrotasks();

        for (var i = 0; i < 8; i++) {
          async.elapse(const Duration(seconds: 5));
          api.streamControllers.last.add(const SseEvent.heartbeat());
          async.flushMicrotasks();
        }

        api.nextLoginError = const FeedNetworkException('down');
        async.elapse(const Duration(seconds: 5)); // reaches t=45s, refresh fires and fails
        async.flushMicrotasks();

        expect(statuses.last, ConnectionStatus.reconnecting);

        manager.dispose();
      });
    });

    test('stop() before refresh fires cancels it, no extra login', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final manager = ConnectionManager(api);

        manager.start();
        async.flushMicrotasks();
        expect(api.loginCalls, 1);

        manager.stop();
        async.elapse(const Duration(seconds: 45));
        async.flushMicrotasks();

        expect(api.loginCalls, 1);

        manager.dispose();
      });
    });
  });
}