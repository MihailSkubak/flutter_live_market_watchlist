import 'package:equatable/equatable.dart';

import 'connection_status.dart';

class ConnectionSnapshot extends Equatable {
  final ConnectionStatus status;
  final int reconnectAttempt;

  const ConnectionSnapshot({
    required this.status,
    this.reconnectAttempt = 0,
  });

  static const initial = ConnectionSnapshot(status: ConnectionStatus.initial);

  ConnectionSnapshot copyWith({ConnectionStatus? status, int? reconnectAttempt}) {
    return ConnectionSnapshot(
      status: status ?? this.status,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    );
  }

  @override
  List<Object?> get props => [status, reconnectAttempt];
}