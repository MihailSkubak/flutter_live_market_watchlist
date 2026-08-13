/// Secure, platform-backed storage for the current auth token.
abstract class TokenStorage {
  Future<void> save(String token);
  Future<String?> read();
  Future<void> delete();
}