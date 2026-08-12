part of 'watchlist_bloc.dart';

sealed class WatchlistEvent extends Equatable {
  const WatchlistEvent();

  @override
  List<Object?> get props => [];
}

class WatchlistStarted extends WatchlistEvent {
  final List<Instrument> instruments;
  const WatchlistStarted(this.instruments);

  @override
  List<Object?> get props => [instruments];
}

class WatchlistStopped extends WatchlistEvent {
  const WatchlistStopped();
}

class _WatchlistTicksFlushed extends WatchlistEvent {
  const _WatchlistTicksFlushed();
}

class _WatchlistConnectionStatusChanged extends WatchlistEvent {
  final ConnectionSnapshot snapshot;
  const _WatchlistConnectionStatusChanged(this.snapshot);

  @override
  List<Object?> get props => [snapshot];
}