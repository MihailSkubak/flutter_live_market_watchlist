import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_live_market_watchlist/feed/resilience/reconnect_backoff.dart';

void main() {
  group('ReconnectBackoff', () {
    test('grows exponentially up to the cap', () {
      final backoff = ReconnectBackoff(
        initialDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 30),
        random: Random(1), // deterministic jitter for the test
      );

      final delays = List.generate(8, (_) => backoff.nextDelay());

      // Roughly doubling each time (within jitter tolerance).
      for (var i = 1; i < 5; i++) {
        expect(
          delays[i].inMilliseconds,
          greaterThan(delays[i - 1].inMilliseconds * 1.5),
        );
      }

      // Never exceeds max + jitter margin.
      for (final d in delays) {
        expect(d.inMilliseconds, lessThanOrEqualTo(33000));
      }
    });

    test('reset() restarts the sequence from the initial delay', () {
      final backoff = ReconnectBackoff(
        initialDelay: const Duration(seconds: 1),
        random: Random(1),
      );

      backoff.nextDelay();
      backoff.nextDelay();
      backoff.nextDelay();
      backoff.reset();

      final afterReset = backoff.nextDelay();
      expect(afterReset.inMilliseconds, inInclusiveRange(900, 1100));
    });

    test('jitter keeps delay within ±10% of the raw exponential value', () {
      final backoff = ReconnectBackoff(
        initialDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 100),
        random: Random(7),
      );

      backoff.nextDelay(); // attempt 0 -> raw 1000ms
      final second = backoff.nextDelay(); // attempt 1 -> raw 2000ms

      expect(second.inMilliseconds, inInclusiveRange(1800, 2200));
    });
  });
}