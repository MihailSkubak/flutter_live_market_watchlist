import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_live_market_watchlist/feed/models/connection_status.dart';

import '../../instrument_detail/instrument_detail_screen.dart';
import '../bloc/watchlist_bloc.dart';
import '../models/flash_direction.dart';

class WatchlistRow extends StatefulWidget {
  final String symbol;

  const WatchlistRow({required this.symbol, super.key});

  @override
  State<WatchlistRow> createState() => _WatchlistRowState();
}

class _WatchlistRowState extends State<WatchlistRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  late Animation<Color?> _flashColorAnimation;
  int _lastSeenFlashSeq = 0;
  Color _baseFlashColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flashColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.transparent,
    ).animate(_flashController);
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _triggerFlash(FlashDirection direction) {
    _baseFlashColor = direction == FlashDirection.up
        ? Colors.green.withValues(alpha: 0.25)
        : Colors.red.withValues(alpha: 0.25);
    _flashColorAnimation = ColorTween(
      begin: _baseFlashColor,
      end: Colors.transparent,
    ).animate(_flashController);
    _flashController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final (item, isLive) = context.select(
      (WatchlistBloc bloc) => (
        bloc.state.items[widget.symbol]!,
        bloc.state.connectionStatus == ConnectionStatus.live,
      ),
    );

    if (item.flashSeq != _lastSeenFlashSeq) {
      _lastSeenFlashSeq = item.flashSeq;
      if (item.flash != FlashDirection.none) {
        _triggerFlash(item.flash);
      }
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<WatchlistBloc>(),
            child: InstrumentDetailScreen(symbol: widget.symbol),
          ),
        ),
      ),
      child: AnimatedBuilder(
  animation: _flashColorAnimation,
  child: AnimatedOpacity(
          opacity: isLive ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  item.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              const Spacer(),
              _PriceColumn(label: 'Bid', value: item.bid, decimals: item.decimals, hasData: item.hasData),
              const SizedBox(width: 24),
              _PriceColumn(label: 'Ask', value: item.ask, decimals: item.decimals, hasData: item.hasData),
            ],
          ),
        ),
        builder: (context, child) {
          return Container(
            color: _flashColorAnimation.value,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          );
        },
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  final String label;
  final double value;
  final int decimals;
  final bool hasData;

  const _PriceColumn({
    required this.label,
    required this.value,
    required this.decimals,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(
          hasData ? value.toStringAsFixed(decimals) : '—',
          style: const TextStyle(fontSize: 15, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}