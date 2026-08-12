import 'package:equatable/equatable.dart';

import '../../../feed/models/instrument.dart';
import '../../../feed/models/price_tick.dart';
import 'flash_direction.dart';

/// Per-symbol UI state. [flashSeq] increments only on a real price move,
/// so the widget can retrigger its flash animation even when the
/// direction repeats (up, then up again) -- comparing [flash] alone
/// wouldn't catch that.
class WatchlistItemState extends Equatable {
  final String symbol;
  final int decimals;
  final double bid;
  final double ask;
  final bool hasData;
  final FlashDirection flash;
  final int flashSeq;

  const WatchlistItemState({
    required this.symbol,
    required this.decimals,
    required this.bid,
    required this.ask,
    required this.hasData,
    required this.flash,
    required this.flashSeq,
  });

  factory WatchlistItemState.initial(Instrument instrument) => WatchlistItemState(
        symbol: instrument.symbol,
        decimals: instrument.decimals,
        bid: 0,
        ask: 0,
        hasData: false,
        flash: FlashDirection.none,
        flashSeq: 0,
      );

  WatchlistItemState applyTick(PriceTick tick) {
    final direction = !hasData
        ? FlashDirection.none
        : tick.bid > bid
            ? FlashDirection.up
            : tick.bid < bid
                ? FlashDirection.down
                : FlashDirection.none;

    return WatchlistItemState(
      symbol: symbol,
      decimals: decimals,
      bid: tick.bid,
      ask: tick.ask,
      hasData: true,
      flash: direction,
      flashSeq: direction == FlashDirection.none ? flashSeq : flashSeq + 1,
    );
  }

  @override
  List<Object?> get props => [symbol, decimals, bid, ask, hasData, flash, flashSeq];
}