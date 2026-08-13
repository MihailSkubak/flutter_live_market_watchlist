import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watchlist_bloc.dart';
import '../models/flash_direction.dart';

class WatchlistRow extends StatefulWidget {
  final String symbol;

  const WatchlistRow({required this.symbol, super.key});

  @override
  State<WatchlistRow> createState() => _WatchlistRowState();
}

class _WatchlistRowState extends State<WatchlistRow> {
  int _lastSeenFlashSeq = 0;
  Color? _flashColor;

  @override
  Widget build(BuildContext context) {
    // Subscribes ONLY to this row's own entry in the items map -- a tick
    // for any other symbol does not rebuild this widget.
    final item = context.select(
      (WatchlistBloc bloc) => bloc.state.items[widget.symbol]!,
    );

    if (item.flashSeq != _lastSeenFlashSeq) {
      _lastSeenFlashSeq = item.flashSeq;
      _flashColor = item.flash == FlashDirection.up
          ? Colors.green.withValues(alpha: 0.25)
          : item.flash == FlashDirection.down
              ? Colors.red.withValues(alpha: 0.25)
              : null;
    }

    return TweenAnimationBuilder<Color?>(
      key: ValueKey(item.flashSeq),
      tween: ColorTween(begin: _flashColor, end: Colors.transparent),
      duration: const Duration(milliseconds: 500),
      builder: (context, color, child) {
        return Container(
          color: color,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        );
      },
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