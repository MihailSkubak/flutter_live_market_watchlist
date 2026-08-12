import 'dart:convert';

import 'sse_event.dart';

/// Parses raw SSE lines into [SseEvent]s. One event = consecutive
/// non-blank lines terminated by a blank line. A bare "': ping'" line
/// with nothing else is a heartbeat comment.
class SseLineParser {
  int? _pendingId;
  String? _pendingEvent;
  String? _pendingData;
  bool _sawCommentOnlyLine = false;

  SseEvent? feedLine(String line) {
    if (line.isEmpty) return _flush();

    if (line.startsWith(':')) {
      _sawCommentOnlyLine = true;
      return null;
    }

    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return null;

    final field = line.substring(0, colonIndex);
    var value = line.substring(colonIndex + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'id':
        _pendingId = int.tryParse(value);
      case 'event':
        _pendingEvent = value;
      case 'data':
        _pendingData = value;
    }
    return null;
  }

  SseEvent? _flush() {
    final event = _pendingEvent;
    final rawData = _pendingData;
    final id = _pendingId;
    final wasCommentOnly = _sawCommentOnlyLine && event == null && rawData == null;

    _pendingId = null;
    _pendingEvent = null;
    _pendingData = null;
    _sawCommentOnlyLine = false;

    if (wasCommentOnly) return const SseEvent.heartbeat();

    // Truly nothing accumulated (e.g. stray blank line) -> ignore.
    if (event == null && rawData == null) return null;

    // Data without a usable event line (or vice versa): the chaos
    // server's raw garbage injection is exactly this case.
    if (rawData == null) return SseEvent.malformed();

    Map<String, dynamic>? decoded;
    try {
      final parsed = jsonDecode(rawData);
      if (parsed is Map<String, dynamic>) decoded = parsed;
    } catch (_) {}

    if (decoded == null) return SseEvent.malformed(rawData: rawData);

    switch (event) {
      case 'tick':
        if (id == null) return SseEvent.malformed(rawData: rawData);
        return SseEvent.tick(id: id, data: decoded);
      case 'gap':
        return SseEvent.gap(data: decoded);
      default:
        return SseEvent.malformed(rawData: rawData);
    }
  }

  static Stream<SseEvent> transform(Stream<String> lines) async* {
    final parser = SseLineParser();
    await for (final line in lines) {
      final event = parser.feedLine(line);
      if (event != null) yield event;
    }
  }
}