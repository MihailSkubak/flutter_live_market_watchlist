import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_live_market_watchlist/feed/transport/sse_event.dart';
import 'package:flutter_live_market_watchlist/feed/transport/sse_line_parser.dart';

void main() {
  group('SseLineParser', () {
    test('parses a well-formed tick event', () {
      final parser = SseLineParser();
      expect(parser.feedLine('id: 1042'), isNull);
      expect(parser.feedLine('event: tick'), isNull);
      expect(
        parser.feedLine('data: {"s":"EURUSD","b":1.08123,"a":1.08141,"ts":1752912000123}'),
        isNull,
      );
      final event = parser.feedLine('');

      expect(event, isNotNull);
      expect(event!.kind, SseEventKind.tick);
      expect(event.id, 1042);
      expect(event.data!['s'], 'EURUSD');
      expect(event.data!['b'], 1.08123);
    });

    test('parses a heartbeat comment line', () {
      final parser = SseLineParser();
      expect(parser.feedLine(': ping'), isNull);
      final event = parser.feedLine('');

      expect(event, isNotNull);
      expect(event!.kind, SseEventKind.heartbeat);
    });

    test('parses a gap event', () {
      final parser = SseLineParser();
      parser.feedLine('event: gap');
      parser.feedLine('data: {"resumeFrom":1500}');
      final event = parser.feedLine('');

      expect(event!.kind, SseEventKind.gap);
      expect(event.data!['resumeFrom'], 1500);
    });

    test('treats unparseable JSON data as malformed, not a crash', () {
      final parser = SseLineParser();
      parser.feedLine('event: tick');
      parser.feedLine('data: ###garbage-not-json###');
      final event = parser.feedLine('');

      expect(event!.kind, SseEventKind.malformed);
      expect(event.rawData, '###garbage-not-json###');
    });

    test('treats a bare "data: ###garbage###" with no event field as malformed',
        () {
      // Mirrors feed_server.dart's scheduleGlobalChaos garbage injection,
      // which sends ONLY a data line with no id/event at all.
      final parser = SseLineParser();
      parser.feedLine('data: ###garbage-not-json###');
      final event = parser.feedLine('');

      expect(event!.kind, SseEventKind.malformed);
    });

    test('tick event missing an id is treated as malformed, not guessed', () {
      final parser = SseLineParser();
      parser.feedLine('event: tick');
      parser.feedLine('data: {"s":"EURUSD","b":1.0,"a":1.0,"ts":1}');
      final event = parser.feedLine('');

      expect(event!.kind, SseEventKind.malformed);
    });

    test('parser instance can be reused across multiple sequential events', () {
      final parser = SseLineParser();
      parser.feedLine('id: 1');
      parser.feedLine('event: tick');
      parser.feedLine('data: {"s":"EURUSD","b":1.0,"a":1.0,"ts":1}');
      final first = parser.feedLine('');

      parser.feedLine(': ping');
      final second = parser.feedLine('');

      parser.feedLine('id: 2');
      parser.feedLine('event: tick');
      parser.feedLine('data: {"s":"GBPUSD","b":1.2,"a":1.2,"ts":2}');
      final third = parser.feedLine('');

      expect(first!.kind, SseEventKind.tick);
      expect(second!.kind, SseEventKind.heartbeat);
      expect(third!.kind, SseEventKind.tick);
      expect(third.id, 2);
    });

    test('SseLineParser.transform parses a stream of raw lines end-to-end', () async {
      final lines = Stream<String>.fromIterable([
        'id: 1',
        'event: tick',
        'data: {"s":"EURUSD","b":1.08123,"a":1.08141,"ts":1}',
        '',
        ': ping',
        '',
        'event: tick',
        'data: not-json',
        '',
      ]);

      final events = await SseLineParser.transform(lines).toList();

      expect(events, hasLength(3));
      expect(events[0].kind, SseEventKind.tick);
      expect(events[1].kind, SseEventKind.heartbeat);
      expect(events[2].kind, SseEventKind.malformed);
    });
  });
}