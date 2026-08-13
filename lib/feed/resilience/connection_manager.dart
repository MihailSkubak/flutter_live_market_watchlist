import 'dart:async';

import 'package:injectable/injectable.dart';

import '../models/connection_snapshot.dart';
import '../models/connection_status.dart';
import '../transport/feed_api.dart';
import '../transport/sse_event.dart';
import 'reconnect_backoff.dart';

/// Owns the login -> SSE stream -> reconnect lifecycle, stall detection,
/// and proactive token refresh. Pure Dart, no Flutter dependency.
/// Forwards every [SseEvent] as-is; dedup/ordering is handled downstream.
@lazySingleton
class ConnectionManager {
  static const _stallTimeout = Duration(seconds: 12);
  // Server tokens expire after 60s; refresh a bit early so we swap before
  // the server drops us, rather than reacting to a 401 after the fact.
  static const _tokenRefreshMargin = Duration(seconds: 15);

  final FeedApi _api;
  final ReconnectBackoff _backoff;

  ConnectionManager(this._api) : _backoff = ReconnectBackoff();

  final _statusController = StreamController<ConnectionSnapshot>.broadcast();
  final _eventController = StreamController<SseEvent>.broadcast();

  Stream<ConnectionSnapshot> get statusStream => _statusController.stream;
  Stream<SseEvent> get events => _eventController.stream;

  String? _token;
  int? _lastEventId;
  StreamSubscription<SseEvent>? _streamSub;
  Timer? _reconnectTimer;
  Timer? _stallTimer;
  Timer? _refreshTimer;
  bool _stopped = true;
  ConnectionSnapshot _snapshot = ConnectionSnapshot.initial;

  void start() {
    if (!_stopped) return;
    _stopped = false;
    _backoff.reset();
    _connect();
  }

  void stop() {
    _stopped = true;
    _cancelTimers();
    _cancelStreamSub();
    _emit(_snapshot.copyWith(status: ConnectionStatus.initial));
  }

  void _cancelStreamSub() {
    final sub = _streamSub;
    _streamSub = null;
    sub?.cancel().catchError((_) {});
  }

  void dispose() {
    stop();
    _statusController.close();
    _eventController.close();
  }

  Future<void> _connect() async {
    if (_stopped) return;
    _emit(_snapshot.copyWith(status: ConnectionStatus.connecting));
    try {
      final token = await _api.login();
      if (_stopped) return;
      _token = token.value;
      _armRefreshTimer(token.expiresInSeconds);
      _subscribeToStream();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _subscribeToStream() {
    _backoff.reset();
    _emit(_snapshot.copyWith(status: ConnectionStatus.live, reconnectAttempt: 0));
    _armStallTimer();
    _streamSub = _api
        .openStream(token: _token!, lastEventId: _lastEventId)
        .listen(_handleEvent, onError: (_) => _scheduleReconnect(), onDone: _scheduleReconnect);
  }

  void _handleEvent(SseEvent event) {
    _armStallTimer();
    if (event.kind == SseEventKind.tick) {
      _lastEventId = event.id;
    }
    _eventController.add(event);
  }

  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallTimeout, _handleStall);
  }

  void _handleStall() {
    if (_stopped) return;
    _emit(_snapshot.copyWith(status: ConnectionStatus.stalled));
    _scheduleReconnect();
  }

  void _armRefreshTimer(int expiresInSeconds) {
    _refreshTimer?.cancel();
    final delay = Duration(seconds: expiresInSeconds) - _tokenRefreshMargin;
    // Guard against a server-configured lifetime shorter than our margin.
    _refreshTimer = Timer(delay.isNegative ? Duration.zero : delay, _refreshToken);
  }

  /// Re-logs in and swaps the SSE connection to the new token, without
  /// touching the backoff/attempt counter -- this is a planned rotation,
  /// not a failure. Last-Event-ID makes the brief swap gap-free.
  Future<void> _refreshToken() async {
    if (_stopped) return;
    _stallTimer?.cancel();
    _cancelStreamSub();
    try {
      final token = await _api.login();
      if (_stopped) return;
      _token = token.value;
      _armRefreshTimer(token.expiresInSeconds);
      _subscribeToStream();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    _cancelTimers();
    _cancelStreamSub();
    final delay = _backoff.nextDelay();
    _emit(_snapshot.copyWith(
      status: ConnectionStatus.reconnecting,
      reconnectAttempt: _snapshot.reconnectAttempt + 1,
    ));
    _reconnectTimer = Timer(delay, _connect);
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
    _refreshTimer?.cancel();
  }

  void _emit(ConnectionSnapshot snapshot) {
    _snapshot = snapshot;
    _statusController.add(snapshot);
  }
}