import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watchlist_bloc.dart';
import 'watchlist_row.dart';

class WatchlistListView extends StatelessWidget {
  const WatchlistListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Selecting only the (stable) set of symbols -- this list is fixed
    // once WatchlistStarted has run, so this widget never rebuilds on a
    // price flush. Each row subscribes to its own symbol independently.
    final symbols = context.select(
      (WatchlistBloc bloc) => bloc.state.items.keys.toList(growable: false),
    );

    return ListView.builder(
      itemCount: symbols.length,
      itemExtent: 64,
      itemBuilder: (context, index) => WatchlistRow(symbol: symbols[index]),
    );
  }
}