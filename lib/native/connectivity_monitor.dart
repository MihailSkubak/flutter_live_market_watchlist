/// Native network reachability, sourced from NWPathMonitor (iOS) or
/// ConnectivityManager (Android). Emits the current state immediately on
/// listen, then on every change.
abstract class ConnectivityMonitor {
  Stream<bool> get isOnline;
}