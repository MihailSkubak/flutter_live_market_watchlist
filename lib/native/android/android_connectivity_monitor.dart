import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../connectivity_monitor.dart';

@LazySingleton(as: ConnectivityMonitor)
class AndroidConnectivityMonitor implements ConnectivityMonitor {
  static const _channel = EventChannel('pulse/connectivity');

  @override
  Stream<bool> get isOnline =>
      _channel.receiveBroadcastStream().map((event) => event as bool);
}