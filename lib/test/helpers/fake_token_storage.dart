import 'package:flutter_live_market_watchlist/native/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  String? saved;
  int saveCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> save(String token) async {
    saved = token;
    saveCalls++;
  }

  @override
  Future<String?> read() async => saved;

  @override
  Future<void> delete() async {
    saved = null;
    deleteCalls++;
  }
}