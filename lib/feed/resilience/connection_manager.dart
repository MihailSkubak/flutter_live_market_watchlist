import 'dart:async';

import 'package:flutter_live_market_watchlist/native/token_storage.dart';
import 'package:injectable/injectable.dart';

import '../../native/connectivity_monitor.dart';
import '../models/connection_snapshot.dart';
import '../models/connection_status.dart';
import '../transport/feed_api.dart';
import '../transport/sse_event.dart';
import 'reconnect_backoff.dart';

/// Owns the login -> SSE stream -> reconnect lifecycle, stall detection,
/// proactive token refresh, and offline suppression. Pure Dart, no
/// Flutter dependency. Forwards every [SseEvent] as-is; dedup/ordering is
/// handled downstream.
@lazySingleton
class ConnectionManager {
  static const _stallTimeout = Duration(seconds: 12);
  static const _tokenRefreshMargin = Duration(seconds: 15);

  final FeedApi _api;
  final ConnectivityMonitor _connectivity;
  final ReconnectBackoff _backoff;
  final TokenStorage _tokenStorage;

  ConnectionManager(this._api, this._connectivity, this._tokenStorage) : _backoff = ReconnectBackoff();

  final _statusController = StreamController<ConnectionSnapshot>.broadcast();
  final _eventController = StreamController<SseEvent>.broadcast();

  Stream<ConnectionSnapshot> get statusStream => _statusController.stream;
  Stream<SseEvent> get events => _eventController.stream;

  String? _token;
  int? _lastEventId;
  StreamSubscription<SseEvent>? _streamSub;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _reconnectTimer;
  Timer? _stallTimer;
  Timer? _refreshTimer;
  bool _stopped = true;
  bool _isOnline = true;
  ConnectionSnapshot _snapshot = ConnectionSnapshot.initial;

  void start() {
    if (!_stopped) return;
    _stopped = false;
    _backoff.reset();
    _connectivitySub = _connectivity.isOnline.listen(_handleConnectivityChanged);
    _connect();
  }

  void stop() {
    _stopped = true;
    _cancelTimers();
    _cancelStreamSub();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    unawaited(_tokenStorage.delete());
    _emit(_snapshot.copyWith(status: ConnectionStatus.initial));
  }

  void dispose() {
    stop();
    _statusController.close();
    _eventController.close();
  }

  void _handleConnectivityChanged(bool isOnline) {
    final wasOnline = _isOnline;
    _isOnline = isOnline;
    if (_stopped) return;

    if (!isOnline) {
      _cancelTimers();
      _cancelStreamSub();
      _emit(_snapshot.copyWith(status: ConnectionStatus.offline));
    } else if (!wasOnline) {
      // Coming back online after being offline: retry immediately rather
      // than waiting out a stale backoff delay.
      _backoff.reset();
      _connect();
    }
  }

  Future<void> _connect() async {
    if (_stopped || !_isOnline) return;
    _emit(_snapshot.copyWith(status: ConnectionStatus.connecting));
    try {
      final token = await _api.login();
      if (_stopped || !_isOnline) return;
      _token = token.value;
      unawaited(_tokenStorage.save(_token!));
      // check secure storage
      //_tokenStorage.read().then((t) => print('token storage round-trip: ${t?.substring(0, 8)}...'));
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
    _refreshTimer = Timer(delay.isNegative ? Duration.zero : delay, _refreshToken);
  }

  Future<void> _refreshToken() async {
    if (_stopped || !_isOnline) return;
    _stallTimer?.cancel();
    _cancelStreamSub();
    try {
      final token = await _api.login();
      if (_stopped || !_isOnline) return;
      _token = token.value;
      unawaited(_tokenStorage.save(_token!));
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

    if (!_isOnline) {
      // No point burning a backoff cycle against a network that isn't
      // there; _handleConnectivityChanged will retry as soon as it is.
      _emit(_snapshot.copyWith(status: ConnectionStatus.offline));
      return;
    }

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

  void _cancelStreamSub() {
    final sub = _streamSub;
    _streamSub = null;
    sub?.cancel().catchError((_) {});
  }

  void _emit(ConnectionSnapshot snapshot) {
    _snapshot = snapshot;
    _statusController.add(snapshot);
  }
}