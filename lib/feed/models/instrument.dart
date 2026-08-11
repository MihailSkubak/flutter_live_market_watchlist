import 'package:equatable/equatable.dart';

/// Static metadata about a tradeable instrument, as returned by GET /instruments.
/// This does NOT change over the lifetime of the app (unlike PriceTick).
class Instrument extends Equatable {
  final String symbol;
  final String name;
  final int decimals;

  const Instrument({
    required this.symbol,
    required this.name,
    required this.decimals,
  });

  factory Instrument.fromJson(Map<String, dynamic> json) {
    return Instrument(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      decimals: json['decimals'] as int,
    );
  }

  @override
  List<Object?> get props => [symbol, name, decimals];
}