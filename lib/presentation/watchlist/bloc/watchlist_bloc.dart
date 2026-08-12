import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../feed/models/connection_snapshot.dart';
import '../../../feed/models/connection_status.dart';
import '../../../feed/models/instrument.dart';
import '../../../feed/models/price_tick.dart';
import '../../../feed/resilience/connection_manager.dart';
import '../../../feed/resilience/tick_ordering_guard.dart';
import '../../../feed/transport/sse_event.dart';
import '../models/watchlist_item_state.dart';

part 'watchlist_event.dart';
part 'watchlist_state.dart';

/// Coalesces bursts of ticks into one state emission roughly every 16ms
/// (~60fps) instead of emitting on every tick -- this is what keeps the
/// watchlist smooth during a 200+ tick burst. Raw ticks are buffered
/// per-symbol between flushes; only the latest tick per symbol survives
/// a flush window.
@injectable
class WatchlistBloc extends Bloc<WatchlistEvent, WatchlistState> {
  static const _flushInterval = Duration(milliseconds: 16);

  final ConnectionManager _connectionManager;
  final TickOrderingGuard _orderingGuard;

  StreamSubscription<SseEvent>? _eventsSub;
  StreamSubscription<ConnectionSnapshot>? _statusSub;
  Timer? _flushTimer;
  final Map<String, PriceTick> _pendingTicks = {};

  WatchlistBloc(this._connectionManager, this._orderingGuard)
      : super(WatchlistState.initial) {
    on<WatchlistStarted>(_onStarted);
    on<WatchlistStopped>(_onStopped);
    on<_WatchlistTicksFlushed>(_onTicksFlushed);
    on<_WatchlistConnectionStatusChanged>(_onStatusChanged);
  }

  void _onStarted(WatchlistStarted event, Emitter<WatchlistState> emit) {
    final items = {
      for (final instrument in event.instruments)
        instrument.symbol: WatchlistItemState.initial(instrument),
    };
    emit(state.copyWith(items: items));

    _statusSub = _connectionManager.statusStream.listen(
      (snapshot) => add(_WatchlistConnectionStatusChanged(snapshot)),
    );
    _eventsSub = _connectionManager.events.listen(_bufferTick);
    _flushTimer = Timer.periodic(
      _flushInterval,
      (_) => add(const _WatchlistTicksFlushed()),
    );

    _connectionManager.start();
  }

  void _bufferTick(SseEvent event) {
    if (event.kind != SseEventKind.tick) return;
    final tick = PriceTick.fromJson(event.data!, id: event.id!);
    if (!_orderingGuard.accept(tick)) return;
    _pendingTicks[tick.symbol] = tick;
  }

  void _onTicksFlushed(
    _WatchlistTicksFlushed event,
    Emitter<WatchlistState> emit,
  ) {
    if (_pendingTicks.isEmpty) return;

    final updated = Map<String, WatchlistItemState>.of(state.items);
    for (final tick in _pendingTicks.values) {
      final previous = updated[tick.symbol];
      if (previous == null) continue; // defensive: unknown symbol
      updated[tick.symbol] = previous.applyTick(tick);
    }
    _pendingTicks.clear();
    emit(state.copyWith(items: updated));
  }

  void _onStatusChanged(
    _WatchlistConnectionStatusChanged event,
    Emitter<WatchlistState> emit,
  ) {
    emit(state.copyWith(connectionStatus: event.snapshot.status));
  }

  void _onStopped(WatchlistStopped event, Emitter<WatchlistState> emit) {
    _teardown();
    emit(state.copyWith(connectionStatus: ConnectionStatus.initial));
  }

  void _teardown() {
    _flushTimer?.cancel();
    _eventsSub?.cancel();
    _statusSub?.cancel();
    _connectionManager.stop();
  }

  @override
  Future<void> close() {
    _teardown();
    return super.close();
  }
}