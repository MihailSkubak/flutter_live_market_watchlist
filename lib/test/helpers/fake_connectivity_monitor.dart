import 'dart:async';

import 'package:flutter_live_market_watchlist/native/connectivity_monitor.dart';

class FakeConnectivityMonitor implements ConnectivityMonitor {
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get isOnline => _controller.stream;

  void setOnline(bool online) => _controller.add(online);

  void dispose() => _controller.close();
}