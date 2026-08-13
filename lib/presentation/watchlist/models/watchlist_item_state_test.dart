import 'package:flutter_live_market_watchlist/presentation/watchlist/models/flash_direction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_live_market_watchlist/feed/models/instrument.dart';
import 'package:flutter_live_market_watchlist/feed/models/price_tick.dart';
import 'package:flutter_live_market_watchlist/presentation/watchlist/models/watchlist_item_state.dart';

const _instrument = Instrument(symbol: 'EURUSD', name: 'Euro / US Dollar', decimals: 5);

PriceTick _tick(double bid, {int ts = 1}) {
  return PriceTick(symbol: 'EURUSD', bid: bid, ask: bid + 0.0001, ts: ts, id: ts);
}

void main() {
  group('WatchlistItemState', () {
    test('initial state has no session high/low and an empty sparkline buffer', () {
      final state = WatchlistItemState.initial(_instrument);
      expect(state.sessionHigh, isNull);
      expect(state.sessionLow, isNull);
      expect(state.recentBids, isEmpty);
    });

    test('first tick seeds session high and low to that bid', () {
      final state = WatchlistItemState.initial(_instrument).applyTick(_tick(1.1000, ts: 1));
      expect(state.sessionHigh, 1.1000);
      expect(state.sessionLow, 1.1000);
      expect(state.recentBids, [1.1000]);
    });

    test('session high/low track the extremes across multiple ticks', () {
      var state = WatchlistItemState.initial(_instrument);
      state = state.applyTick(_tick(1.1000, ts: 1));
      state = state.applyTick(_tick(1.1050, ts: 2));
      state = state.applyTick(_tick(1.0950, ts: 3));
      state = state.applyTick(_tick(1.1020, ts: 4));

      expect(state.sessionHigh, 1.1050);
      expect(state.sessionLow, 1.0950);
    });

    test('recentBids buffer is capped at 50 entries, dropping the oldest', () {
      var state = WatchlistItemState.initial(_instrument);
      for (var i = 0; i < 60; i++) {
        state = state.applyTick(_tick(1.1000 + i * 0.0001, ts: i + 1));
      }

      expect(state.recentBids.length, 50);
      // The first 10 ticks (indices 0..9) should have been dropped.
      expect(state.recentBids.first, closeTo(1.1010, 0.00001));
      expect(state.recentBids.last, closeTo(1.1059, 0.00001));
    });

    test('applyTick still computes flash direction correctly alongside history', () {
      var state = WatchlistItemState.initial(_instrument);
      state = state.applyTick(_tick(1.1000, ts: 1));
      state = state.applyTick(_tick(1.1010, ts: 2));

      expect(state.flash, FlashDirection.up);
      expect(state.sessionHigh, 1.1010);
    });
  });
}