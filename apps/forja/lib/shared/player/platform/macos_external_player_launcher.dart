import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens a stream URL in an external macOS app via NSWorkspace (sandbox-safe).
class MacosExternalPlayerLauncher {
  static const _channel = MethodChannel('forja.macos/external_player');

  static Future<bool> launchUrl({
    required String appPath,
    required String url,
  }) async {
    if (!Platform.isMacOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('launchUrl', {
        'appPath': appPath,
        'url': url,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ExternalPlayer] NSWorkspace launch failed: ${e.code} ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('[ExternalPlayer] NSWorkspace launch error: $e');
      return false;
    }
  }
}
