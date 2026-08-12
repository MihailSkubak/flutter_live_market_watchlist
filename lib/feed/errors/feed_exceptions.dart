/// Thrown on 401 — expired/invalid token. Callers should re-login, not retry.
class FeedAuthException implements Exception {
  const FeedAuthException();
}

/// Any other transport failure (timeout, connection refused, dropped mid-stream).
class FeedNetworkException implements Exception {
  final String message;
  const FeedNetworkException(this.message);

  @override
  String toString() => 'FeedNetworkException: $message';
}