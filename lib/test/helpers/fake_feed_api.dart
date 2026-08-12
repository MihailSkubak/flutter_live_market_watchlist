import 'dart:async';

import 'package:flutter_live_market_watchlist/feed/models/auth_token.dart';
import 'package:flutter_live_market_watchlist/feed/models/instrument.dart';
import 'package:flutter_live_market_watchlist/feed/transport/feed_api.dart';
import 'package:flutter_live_market_watchlist/feed/transport/sse_event.dart';

class FakeFeedApi implements FeedApi {
  int loginCalls = 0;
  Object? nextLoginError;
  Object? nextInstrumentsError;
  List<Instrument> instrumentsToReturn = const [];
  final streamControllers = <StreamController<SseEvent>>[];
  final lastEventIdsRequested = <int?>[];

  @override
  Future<AuthToken> login() async {
    loginCalls++;
    final err = nextLoginError;
    if (err != null) {
      nextLoginError = null;
      throw err;
    }
    return const AuthToken(value: 'tok', expiresInSeconds: 60);
  }

  @override
  Future<List<Instrument>> fetchInstruments(String token) async {
    final err = nextInstrumentsError;
    if (err != null) {
      nextInstrumentsError = null;
      throw err;
    }
    return instrumentsToReturn;
  }

  @override
  Stream<SseEvent> openStream({required String token, int? lastEventId}) {
    lastEventIdsRequested.add(lastEventId);
    final controller = StreamController<SseEvent>();
    streamControllers.add(controller);
    return controller.stream;
  }
}