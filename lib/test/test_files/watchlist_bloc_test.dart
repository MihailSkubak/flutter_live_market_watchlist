import 'package:fake_async/fake_async.dart';
import 'package:flutter_live_market_watchlist/test/helpers/fake_connectivity_monitor.dart';
import 'package:flutter_live_market_watchlist/test/helpers/fake_feed_api.dart';
import 'package:flutter_live_market_watchlist/test/helpers/fake_token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_live_market_watchlist/feed/errors/feed_exceptions.dart';
import 'package:flutter_live_market_watchlist/feed/models/connection_status.dart';
import 'package:flutter_live_market_watchlist/feed/models/instrument.dart';
import 'package:flutter_live_market_watchlist/feed/resilience/connection_manager.dart';
import 'package:flutter_live_market_watchlist/feed/resilience/tick_ordering_guard.dart';
import 'package:flutter_live_market_watchlist/feed/transport/sse_event.dart';
import 'package:flutter_live_market_watchlist/presentation/watchlist/bloc/watchlist_bloc.dart';
import 'package:flutter_live_market_watchlist/presentation/watchlist/models/flash_direction.dart';


const _instruments = [
  Instrument(symbol: 'EURUSD', name: 'Euro / US Dollar', decimals: 5),
  Instrument(symbol: 'BTCUSD', name: 'Bitcoin', decimals: 2),
];

void main() {
  group('WatchlistBloc', () {
    test('seeds items for each instrument with no data on start', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final bloc = WatchlistBloc(ConnectionManager(api, FakeConnectivityMonitor()..setOnline(true), FakeTokenStorage()), TickOrderingGuard());

        bloc.add(const WatchlistStarted(_instruments));
        async.flushMicrotasks();

        expect(bloc.state.items.keys, containsAll(['EURUSD', 'BTCUSD']));
        expect(bloc.state.items['EURUSD']!.hasData, isFalse);

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('a tick is applied only on the next 16ms flush, not immediately', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final bloc = WatchlistBloc(ConnectionManager(api, FakeConnectivityMonitor()..setOnline(true), FakeTokenStorage()), TickOrderingGuard());
        bloc.add(const WatchlistStarted(_instruments));
        async.flushMicrotasks();

        api.streamControllers.single.add(
          SseEvent.tick(id: 1, data: const {'s': 'EURUSD', 'b': 1.08123, 'a': 1.08141, 'ts': 1000}),
        );
        async.flushMicrotasks();
        expect(bloc.state.items['EURUSD']!.hasData, isFalse);

        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();

        final item = bloc.state.items['EURUSD']!;
        expect(item.hasData, isTrue);
        expect(item.bid, 1.08123);
        expect(item.flash, FlashDirection.none); // nothing to compare against yet

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('flashes up when bid increases and down when bid decreases', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final bloc = WatchlistBloc(ConnectionManager(api, FakeConnectivityMonitor()..setOnline(true), FakeTokenStorage()), TickOrderingGuard());
        bloc.add(const WatchlistStarted(_instruments));
        async.flushMicrotasks();

        api.streamControllers.single.add(
          SseEvent.tick(id: 1, data: const {'s': 'EURUSD', 'b': 1.0, 'a': 1.0, 'ts': 1000}),
        );
        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();
        expect(bloc.state.items['EURUSD']!.flash, FlashDirection.none);

        api.streamControllers.single.add(
          SseEvent.tick(id: 2, data: const {'s': 'EURUSD', 'b': 1.1, 'a': 1.1, 'ts': 2000}),
        );
        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();
        expect(bloc.state.items['EURUSD']!.flash, FlashDirection.up);

        api.streamControllers.single.add(
          SseEvent.tick(id: 3, data: const {'s': 'EURUSD', 'b': 1.05, 'a': 1.05, 'ts': 3000}),
        );
        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();
        expect(bloc.state.items['EURUSD']!.flash, FlashDirection.down);

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('coalesces a burst of same-symbol ticks into a single flush update', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final bloc = WatchlistBloc(ConnectionManager(api, FakeConnectivityMonitor()..setOnline(true), FakeTokenStorage()), TickOrderingGuard());
        bloc.add(const WatchlistStarted(_instruments));
        async.flushMicrotasks();
        
        api.streamControllers.single.add(
          SseEvent.tick(id: 0, data: const {'s': 'BTCUSD', 'b': 64000.0, 'a': 64001.0, 'ts': 999}),
        );
        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();
        expect(bloc.state.items['BTCUSD']!.flashSeq, 0);

        for (var i = 0; i < 50; i++) {
          api.streamControllers.single.add(
            SseEvent.tick(
              id: i,
              data: {'s': 'BTCUSD', 'b': 64000.0 + i, 'a': 64001.0 + i, 'ts': 1000 + i},
            ),
          );
        }
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();

        final item = bloc.state.items['BTCUSD']!;
        expect(item.bid, 64049.0); // only the last tick in the window survives
        expect(item.flashSeq, 1); // fifty ticks coalesced into exactly one flash

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('rejects a stale/duplicate tick via the ordering guard', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final bloc = WatchlistBloc(ConnectionManager(api, FakeConnectivityMonitor()..setOnline(true), FakeTokenStorage()), TickOrderingGuard());
        bloc.add(const WatchlistStarted(_instruments));
        async.flushMicrotasks();

        api.streamControllers.single.add(
          SseEvent.tick(id: 1, data: const {'s': 'EURUSD', 'b': 1.5, 'a': 1.5, 'ts': 5000}),
        );
        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();
        expect(bloc.state.items['EURUSD']!.bid, 1.5);

        api.streamControllers.single.add(
          SseEvent.tick(id: 2, data: const {'s': 'EURUSD', 'b': 1.2, 'a': 1.2, 'ts': 2000}), // older ts
        );
        async.elapse(const Duration(milliseconds: 16));
        async.flushMicrotasks();

        expect(bloc.state.items['EURUSD']!.bid, 1.5); // unchanged

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('reflects connection status changes from ConnectionManager', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final bloc = WatchlistBloc(ConnectionManager(api, FakeConnectivityMonitor()..setOnline(true), FakeTokenStorage()), TickOrderingGuard());

        bloc.add(const WatchlistStarted(_instruments));
        async.flushMicrotasks();
        expect(bloc.state.connectionStatus, ConnectionStatus.live);

        api.streamControllers.single.addError(const FeedNetworkException('dropped'));
        async.flushMicrotasks();
        expect(bloc.state.connectionStatus, ConnectionStatus.reconnecting);

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('WatchlistStopped tears down subscriptions; later ticks have no effect', () {
      fakeAsync((async) {
        final api = FakeFeedApi();
        final bloc = WatchlistBloc(ConnectionManager(api, FakeConnectivityMonitor()..setOnline(true), FakeTokenStorage()), TickOrderingGuard());
        bloc.add(const WatchlistStarted(_instruments));
        async.flushMicrotasks();

        final controller = api.streamControllers.single;
        bloc.add(const WatchlistStopped());
        async.flushMicrotasks();

        controller.add(
          SseEvent.tick(id: 1, data: const {'s': 'EURUSD', 'b': 9.9, 'a': 9.9, 'ts': 1}),
        );
        async.elapse(const Duration(milliseconds: 32));
        async.flushMicrotasks();

        expect(bloc.state.items['EURUSD']!.hasData, isFalse);

        bloc.close();
        async.flushMicrotasks();
      });
    });
  });
}