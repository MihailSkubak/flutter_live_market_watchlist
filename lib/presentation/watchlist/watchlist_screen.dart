import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../instruments/bloc/instruments_bloc.dart';
import 'bloc/watchlist_bloc.dart';
import 'widgets/connection_status_bar.dart';
import 'widgets/watchlist_body.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<InstrumentsBloc>()..add(const InstrumentsRequested()),
        ),
        BlocProvider(create: (_) => getIt<WatchlistBloc>()),
      ],
      child: const Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: ConnectionStatusBar(),
        ),
        body: WatchlistBody(),
      ),
    );
  }
}