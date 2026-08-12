part of 'watchlist_bloc.dart';

class WatchlistState extends Equatable {
  final ConnectionStatus connectionStatus;
  final Map<String, WatchlistItemState> items;

  const WatchlistState({required this.connectionStatus, required this.items});

  static const initial = WatchlistState(
    connectionStatus: ConnectionStatus.initial,
    items: {},
  );

  WatchlistState copyWith({
    ConnectionStatus? connectionStatus,
    Map<String, WatchlistItemState>? items,
  }) {
    return WatchlistState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [connectionStatus, items];
}