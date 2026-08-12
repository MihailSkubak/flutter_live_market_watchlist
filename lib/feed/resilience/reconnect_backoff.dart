import 'dart:math';

/// Exponential backoff with jitter for reconnect delays.
/// Delay doubles each attempt, capped at [maxDelay], with up to 20%
/// random jitter to avoid a thundering herd if many clients reconnect
/// at once.
class ReconnectBackoff {
  final Duration initialDelay;
  final Duration maxDelay;
  final Random _random;

  int _attempt = 0;

  ReconnectBackoff({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    Random? random,
  }) : _random = random ?? Random();

  Duration nextDelay() {
    final exponent = min(_attempt, 10); // guard against overflow at high attempt counts
    final rawMs = initialDelay.inMilliseconds * pow(2, exponent);
    final cappedMs = min(rawMs.toDouble(), maxDelay.inMilliseconds.toDouble());

    final jitterFactor = 1 + (_random.nextDouble() * 0.2 - 0.1); // ±10%
    final jitteredMs = (cappedMs * jitterFactor).round();

    _attempt++;
    return Duration(milliseconds: jitteredMs);
  }

  void reset() => _attempt = 0;
}