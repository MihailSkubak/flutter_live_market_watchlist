import 'package:equatable/equatable.dart';

import '../../../feed/models/instrument.dart';
import '../../../feed/models/price_tick.dart';
import 'flash_direction.dart';

/// Per-symbol UI state. [flashSeq] increments only on a real price move,
/// so the widget can retrigger its flash animation even when the
/// direction repeats (up, then up again) -- comparing [flash] alone
/// wouldn't catch that.
///
/// [sessionHigh]/[sessionLow] and [recentBids] track history since this
/// symbol's first tick in the current app session -- not persisted
/// across restarts, matching the token's own session-scoped lifetime.
class WatchlistItemState extends Equatable {
  static const _sparklineCapacity = 50;

  final String symbol;
  final int decimals;
  final double bid;
  final double ask;
  final bool hasData;
  final FlashDirection flash;
  final int flashSeq;
  final double? sessionHigh;
  final double? sessionLow;
  final List<double> recentBids;

  const WatchlistItemState({
    required this.symbol,
    required this.decimals,
    required this.bid,
    required this.ask,
    required this.hasData,
    required this.flash,
    required this.flashSeq,
    required this.sessionHigh,
    required this.sessionLow,
    required this.recentBids,
  });

  factory WatchlistItemState.initial(Instrument instrument) => WatchlistItemState(
        symbol: instrument.symbol,
        decimals: instrument.decimals,
        bid: 0,
        ask: 0,
        hasData: false,
        flash: FlashDirection.none,
        flashSeq: 0,
        sessionHigh: null,
        sessionLow: null,
        recentBids: const [],
      );

  WatchlistItemState applyTick(PriceTick tick) {
    final direction = !hasData
        ? FlashDirection.none
        : tick.bid > bid
            ? FlashDirection.up
            : tick.bid < bid
                ? FlashDirection.down
                : FlashDirection.none;

    final updatedBids = [...recentBids, tick.bid];
    if (updatedBids.length > _sparklineCapacity) {
      updatedBids.removeAt(0);
    }

    return WatchlistItemState(
      symbol: symbol,
      decimals: decimals,
      bid: tick.bid,
      ask: tick.ask,
      hasData: true,
      flash: direction,
      flashSeq: direction == FlashDirection.none ? flashSeq : flashSeq + 1,
      sessionHigh: sessionHigh == null ? tick.bid : (tick.bid > sessionHigh! ? tick.bid : sessionHigh),
      sessionLow: sessionLow == null ? tick.bid : (tick.bid < sessionLow! ? tick.bid : sessionLow),
      recentBids: updatedBids,
    );
  }

  @override
  List<Object?> get props => [
        symbol,
        decimals,
        bid,
        ask,
        hasData,
        flash,
        flashSeq,
        sessionHigh,
        sessionLow,
        recentBids,
      ];
}