import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../watchlist/bloc/watchlist_bloc.dart';
import '../watchlist/models/watchlist_item_state.dart';
import 'widgets/sparkline_painter.dart';

/// Samples the bloc's state on a fixed 100ms cadence rather than
/// subscribing reactively via context.select. The main watchlist needs
/// per-tick responsiveness across 40 rows; a single detail view does not
/// -- decoupling this screen's rebuild rate from the 16ms flush keeps it
/// cheap even while a burst is driving the background list hard.
class InstrumentDetailScreen extends StatefulWidget {
  final String symbol;

  const InstrumentDetailScreen({required this.symbol, super.key});

  @override
  State<InstrumentDetailScreen> createState() => _InstrumentDetailScreenState();
}

class _InstrumentDetailScreenState extends State<InstrumentDetailScreen> {
  static const _sampleInterval = Duration(milliseconds: 100);

  Timer? _sampleTimer;
  late WatchlistItemState _item;

  @override
  void initState() {
    super.initState();
    _item = context.read<WatchlistBloc>().state.items[widget.symbol]!;
    _sampleTimer = Timer.periodic(_sampleInterval, (_) => _sample());
  }

  void _sample() {
    final latest = context.read<WatchlistBloc>().state.items[widget.symbol]!;
    if (latest != _item) {
      setState(() => _item = latest);
    }
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.symbol)),
      body: _item.hasData
          ? _DetailBody(item: _item)
          : const Center(child: Text('Waiting for data…')),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final WatchlistItemState item;

  const _DetailBody({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PriceBlock(label: 'Bid', value: item.bid, decimals: item.decimals),
              _PriceBlock(label: 'Ask', value: item.ask, decimals: item.decimals),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PriceBlock(
                label: 'Session High',
                value: item.sessionHigh ?? item.bid,
                decimals: item.decimals,
                color: Colors.green.shade700,
              ),
              _PriceBlock(
                label: 'Session Low',
                value: item.sessionLow ?? item.bid,
                decimals: item.decimals,
                color: Colors.red.shade700,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Recent bid movement', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: item.recentBids.length >= 2
                ? RepaintBoundary(
                    child: CustomPaint(painter: SparklinePainter(values: item.recentBids)),
                  )
                : const Center(child: Text('Not enough data yet')),
          ),
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  final String label;
  final double value;
  final int decimals;
  final Color? color;

  const _PriceBlock({
    required this.label,
    required this.value,
    required this.decimals,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(decimals),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}