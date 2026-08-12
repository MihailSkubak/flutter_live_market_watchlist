import 'package:equatable/equatable.dart';

/// The distinct kinds of lines/events the feed's SSE stream can produce,
/// per feed_server.dart's documented behavior:
/// - `tick`: a price update, carries `id` + JSON payload.
/// - `gap`: server couldn't replay from Last-Event-ID, buffer moved on.
/// - `heartbeat`: a `: ping` comment line, no id/data — proves the
///   connection is alive even when no ticks are flowing.
/// - `malformed`: a `data:` payload that failed JSON parsing. Per spec this
///   must not kill the stream — surface it so the caller can log/count it and move on.
enum SseEventKind { tick, gap, heartbeat, malformed }

class SseEvent extends Equatable {
  final SseEventKind kind;

  
  final int? id;

  /// Raw `data:` payload, already JSON-decoded where parseable.
  final Map<String, dynamic>? data;

  /// Raw, undecoded `data:` line content — kept for malformed events so 
  /// it will be possible to log what actually broke, without re-parsing.
  final String? rawData;

  const SseEvent._({
    required this.kind,
    this.id,
    this.data,
    this.rawData,
  });

  factory SseEvent.tick({required int id, required Map<String, dynamic> data}) =>
      SseEvent._(kind: SseEventKind.tick, id: id, data: data);

  factory SseEvent.gap({required Map<String, dynamic> data}) =>
      SseEvent._(kind: SseEventKind.gap, data: data);

  const SseEvent.heartbeat() : this._(kind: SseEventKind.heartbeat);

  factory SseEvent.malformed({String? rawData}) =>
      SseEvent._(kind: SseEventKind.malformed, rawData: rawData);

  @override
  List<Object?> get props => [kind, id, data, rawData];
}