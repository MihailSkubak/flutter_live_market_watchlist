import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
//import 'package:dio/io.dart';
import 'package:injectable/injectable.dart';

import '../errors/feed_exceptions.dart';
import '../models/auth_token.dart';
import '../models/instrument.dart';
import 'feed_api.dart';
import 'sse_event.dart';
import 'sse_line_parser.dart';

@LazySingleton(as: FeedApi)
class DioFeedApi implements FeedApi {
  final Dio _dio;

  // Fixed per the take-home spec; not treated as a real secret.
  static const _username = 'trader';
  static const _password = 'password123';

  DioFeedApi(this._dio);

  @override
  Future<AuthToken> login() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/login',
        data: {'username': _username, 'password': _password},
      );
      final data = response.data!;
      return AuthToken(
        value: data['token'] as String,
        expiresInSeconds: data['expiresIn'] as int,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<List<Instrument>> fetchInstruments(String token) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/instruments',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data!
          .cast<Map<String, dynamic>>()
          .map(Instrument.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Stream<SseEvent> openStream({required String token, int? lastEventId}) {
    late StreamController<SseEvent> controller;
    StreamSubscription<SseEvent>? sub;
    final cancelToken = CancelToken();

    Future<void> start() async {
      try {
        final response = await _dio.get<ResponseBody>(
          '/stream',
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              'Authorization': 'Bearer $token',
              if (lastEventId != null) 'Last-Event-ID': '$lastEventId',
            },
          ),
          cancelToken: cancelToken,
        );

        final lines = utf8.decoder
            .bind(response.data!.stream)
            .transform(const LineSplitter());

        sub = SseLineParser.transform(lines).listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      } on DioException catch (e) {
        controller.addError(_mapError(e));
        await controller.close();
      }
    }

    controller = StreamController<SseEvent>(
      onListen: start,
      onCancel: () {
        cancelToken.cancel('stream cancelled');
        sub?.cancel();
      },
    );

    return controller.stream;
  }

  Exception _mapError(DioException e) {
    if (e.response?.statusCode == 401) return const FeedAuthException();
    return FeedNetworkException(e.message ?? e.type.name);
  }
}