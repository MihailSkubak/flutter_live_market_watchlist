import '../models/auth_token.dart';
import '../models/instrument.dart';
import 'sse_event.dart';

/// Implementations throw [FeedAuthException] on 401 and [FeedNetworkException]
/// on any other failure, so callers can branch without knowing about Dio.
abstract class FeedApi {
  Future<AuthToken> login();
  Future<List<Instrument>> fetchInstruments(String token);
  Stream<SseEvent> openStream({required String token, int? lastEventId});
}