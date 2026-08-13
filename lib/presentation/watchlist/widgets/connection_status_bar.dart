import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/models/connection_status.dart';
import '../bloc/watchlist_bloc.dart';

class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select((WatchlistBloc bloc) => bloc.state.connectionStatus);
    final config = _statusConfig(status);

    return AppBar(
      title: const Text('Pulse'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(28),
        child: Container(
          height: 28,
          color: config.color,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (config.showSpinner)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(config.icon, size: 14, color: Colors.white),
                ),
              Text(
                config.label,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusConfig _statusConfig(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.initial =>
        _StatusConfig('Starting', Colors.grey, Icons.circle_outlined, false),
      ConnectionStatus.connecting =>
        _StatusConfig('Connecting…', Colors.blueGrey, null, true),
      ConnectionStatus.live =>
        _StatusConfig('Live', Colors.green.shade700, Icons.check_circle, false),
      ConnectionStatus.reconnecting =>
        _StatusConfig('Reconnecting…', Colors.orange.shade800, null, true),
      ConnectionStatus.stalled =>
        _StatusConfig('Stalled — data may be outdated', Colors.red.shade700, Icons.warning_amber, false),
      ConnectionStatus.offline =>
        _StatusConfig('Offline', Colors.grey.shade800, Icons.wifi_off, false),
    };
  }
}

class _StatusConfig {
  final String label;
  final Color color;
  final IconData? icon;
  final bool showSpinner;

  _StatusConfig(this.label, this.color, this.icon, this.showSpinner);
}