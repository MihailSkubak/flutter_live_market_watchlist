import 'package:bloc_test/bloc_test.dart';
import '../../../helpers/fake_feed_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_live_market_watchlist/feed/errors/feed_exceptions.dart';
import 'package:flutter_live_market_watchlist/feed/models/instrument.dart';
import 'package:flutter_live_market_watchlist/presentation/instruments/bloc/instruments_bloc.dart';



void main() {
  group('InstrumentsBloc', () {
    const instruments = [
      Instrument(symbol: 'EURUSD', name: 'Euro / US Dollar', decimals: 5),
      Instrument(symbol: 'BTCUSD', name: 'Bitcoin', decimals: 2),
    ];

    blocTest<InstrumentsBloc, InstrumentsState>(
      'emits [loading, loaded] on successful login + fetch',
      build: () => InstrumentsBloc(
        FakeFeedApi()..instrumentsToReturn = instruments,
      ),
      act: (bloc) => bloc.add(const InstrumentsRequested()),
      expect: () => [
        const InstrumentsLoading(),
        const InstrumentsLoaded(instruments),
      ],
    );

    blocTest<InstrumentsBloc, InstrumentsState>(
      'emits [loading, error] when login fails',
      build: () => InstrumentsBloc(
        FakeFeedApi()..nextLoginError = const FeedNetworkException('down'),
      ),
      act: (bloc) => bloc.add(const InstrumentsRequested()),
      expect: () => [
        const InstrumentsLoading(),
        isA<InstrumentsError>(),
      ],
    );

    blocTest<InstrumentsBloc, InstrumentsState>(
      'emits [loading, error] when fetchInstruments fails after successful login',
      build: () => InstrumentsBloc(
        FakeFeedApi()..nextInstrumentsError = const FeedNetworkException('boom'),
      ),
      act: (bloc) => bloc.add(const InstrumentsRequested()),
      expect: () => [
        const InstrumentsLoading(),
        isA<InstrumentsError>(),
      ],
    );
  });
}