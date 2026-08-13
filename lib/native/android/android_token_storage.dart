import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../token_storage.dart';

@LazySingleton(as: TokenStorage)
class AndroidTokenStorage implements TokenStorage {
  static const _channel = MethodChannel('pulse/secure_token');

  @override
  Future<void> save(String token) async {
    await _channel.invokeMethod<void>('save', {'token': token});
  }

  @override
  Future<String?> read() async {
    return _channel.invokeMethod<String?>('read');
  }

  @override
  Future<void> delete() async {
    await _channel.invokeMethod<void>('delete');
  }
}