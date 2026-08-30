import 'package:injectable/injectable.dart';

import '../models/price_tick.dart';

/// Decides whether an incoming [PriceTick] should be applied to on-screen
/// state, or dropped as stale/duplicate.
///
/// A tick is accepted only if its `ts` is strictly newer than the last
/// accepted `ts` for that symbol. This single rule handles both of the
/// feed's chaos modes: exact duplicates (same ts, rejected as not-newer)
/// and out-of-order replays (older ts, rejected the same way).
@lazySingleton
class TickOrderingGuard {
  final _lastApplied = <String, (int ts, int id)>{};

  bool accept(PriceTick tick) {
    final last = _lastApplied[tick.symbol];
    if (last != null) {
      final (lastTs, lastId) = last;
      final isNewer = tick.ts > lastTs || (tick.ts == lastTs && tick.id > lastId);
      if (!isNewer) return false;
    }
    _lastApplied[tick.symbol] = (tick.ts, tick.id);
    return true;
  }

  void reset() => _lastApplied.clear();
}