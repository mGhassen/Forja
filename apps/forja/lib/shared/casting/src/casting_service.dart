import 'dart:io';
import 'package:flutter/foundation.dart';

enum CastTarget { airplay, chromecast }

class CastingService {
  CastingService._();
  static final CastingService instance = CastingService._();

  bool get isAirPlayAvailable =>
      !kIsWeb && (Platform.isMacOS || Platform.isIOS);

  bool get isChromecastAvailable =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows);

  /// v1.1: native platform channel implementation.
  Future<bool> castUrl({
    required String url,
    required CastTarget target,
    Map<String, String>? headers,
    String? title,
  }) async {
    debugPrint('[Casting] ${target.name} cast requested: $url');
    return false;
  }

  Future<void> stopCasting() async {}
}
