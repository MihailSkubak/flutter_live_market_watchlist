/// High-level state of the feed connection, as exposed to the UI.
enum ConnectionStatus {
  /// Never connected yet, or explicitly reset (e.g. app cold start).
  initial,

  /// Actively trying to establish the SSE connection (incl. login).
  connecting,

  /// Connected and receiving ticks/heartbeats within expected cadence.
  live,

  /// Was connected, lost the connection, retrying with backoff.
  reconnecting,

  /// Connection is technically open but no data/heartbeat has arrived
  /// within the expected window — prices on screen may be stale.
  stalled,

  /// Device is known offline (native connectivity signal). 
  offline,
}