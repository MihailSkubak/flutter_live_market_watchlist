import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_live_market_watchlist/feed/models/price_tick.dart';
import 'package:flutter_live_market_watchlist/feed/resilience/tick_ordering_guard.dart';

PriceTick _tick({required String symbol, required int ts, int id = 1}) {
  return PriceTick(symbol: symbol, bid: 1.0, ask: 1.0, ts: ts, id: id);
}

void main() {
  group('TickOrderingGuard', () {
    test('accepts the first tick seen for a symbol', () {
      final guard = TickOrderingGuard();
      expect(guard.accept(_tick(symbol: 'EURUSD', ts: 1000)), isTrue);
    });

    test('accepts a strictly newer tick for the same symbol', () {
      final guard = TickOrderingGuard();
      guard.accept(_tick(symbol: 'EURUSD', ts: 1000));
      expect(guard.accept(_tick(symbol: 'EURUSD', ts: 1001)), isTrue);
    });

    test('rejects an exact duplicate (same ts, same id) -- server duplicate() case', () {
      final guard = TickOrderingGuard();
      guard.accept(_tick(symbol: 'EURUSD', ts: 1000, id: 5));
      final duplicate = _tick(symbol: 'EURUSD', ts: 1000, id: 5);
      expect(guard.accept(duplicate), isFalse);
    });

    test('rejects an older ts under a new id -- server outOfOrder() case', () {
      final guard = TickOrderingGuard();
      guard.accept(_tick(symbol: 'EURUSD', ts: 5000, id: 10));
      final stale = _tick(symbol: 'EURUSD', ts: 2000, id: 11); // new id, old ts
      expect(guard.accept(stale), isFalse);
    });

    test('accepts a same-ts tick with a higher id -- millisecond-resolution burst case', () {
      final guard = TickOrderingGuard();
      guard.accept(_tick(symbol: 'BTCUSD', ts: 1000, id: 1));
      expect(guard.accept(_tick(symbol: 'BTCUSD', ts: 1000, id: 2)), isTrue);
      expect(guard.accept(_tick(symbol: 'BTCUSD', ts: 1000, id: 3)), isTrue);
    });

    test('same ts, lower or equal id is still rejected', () {
      final guard = TickOrderingGuard();
      guard.accept(_tick(symbol: 'BTCUSD', ts: 1000, id: 5));
      expect(guard.accept(_tick(symbol: 'BTCUSD', ts: 1000, id: 5)), isFalse); // the same id
      expect(guard.accept(_tick(symbol: 'BTCUSD', ts: 1000, id: 3)), isFalse); // id less
    });

    test('tracks each symbol independently', () {
      final guard = TickOrderingGuard();
      guard.accept(_tick(symbol: 'EURUSD', ts: 5000));
      expect(guard.accept(_tick(symbol: 'GBPUSD', ts: 100)), isTrue);
    });

    test('reset() clears history so a previously-stale ts is accepted again', () {
      final guard = TickOrderingGuard();
      guard.accept(_tick(symbol: 'EURUSD', ts: 5000));
      guard.reset();
      expect(guard.accept(_tick(symbol: 'EURUSD', ts: 100)), isTrue);
    });
  });
}