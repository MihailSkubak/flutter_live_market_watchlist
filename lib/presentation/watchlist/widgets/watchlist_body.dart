import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../instruments/bloc/instruments_bloc.dart';
import '../bloc/watchlist_bloc.dart';
import 'watchlist_list_view.dart';

class WatchlistBody extends StatelessWidget {
  const WatchlistBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<InstrumentsBloc, InstrumentsState>(
      listener: (context, state) {
        if (state is InstrumentsLoaded) {
          context.read<WatchlistBloc>().add(WatchlistStarted(state.instruments));
        }
      },
      child: BlocBuilder<InstrumentsBloc, InstrumentsState>(
        builder: (context, state) {
          return switch (state) {
            InstrumentsInitial() || InstrumentsLoading() =>
              const Center(child: CircularProgressIndicator()),
            InstrumentsError(:final message) => Center(child: Text(message)),
            InstrumentsLoaded() => const WatchlistListView(),
          };
        },
      ),
    );
  }
}