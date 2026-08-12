import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@module
abstract class NetworkModule {
  @lazySingleton
  Dio dio() => Dio(BaseOptions(
        baseUrl: _feedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
      ));

  static String get _feedBaseUrl {
    // Needed for physical devices, which can't reach 10.0.2.2 or localhost.
    const override = String.fromEnvironment('FEED_HOST');
    if (override.isNotEmpty) return 'http://$override:8080';

    // Android emulator can't resolve the host's localhost; 10.0.2.2 is
    // the documented loopback alias for the AVD host machine.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}