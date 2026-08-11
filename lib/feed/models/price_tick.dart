import 'package:equatable/equatable.dart';

/// A single bid/ask update for one symbol, decoded from an SSE `tick` event.

class PriceTick extends Equatable {
  final String symbol;
  final double bid;
  final double ask;
  final int ts;
  final int id;

  const PriceTick({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.ts,
    required this.id,
  });

  factory PriceTick.fromJson(Map<String, dynamic> json, {required int id}) {
    return PriceTick(
      symbol: json['s'] as String,
      bid: (json['b'] as num).toDouble(),
      ask: (json['a'] as num).toDouble(),
      ts: json['ts'] as int,
      id: id,
    );
  }

  @override
  List<Object?> get props => [symbol, bid, ask, ts, id];
}