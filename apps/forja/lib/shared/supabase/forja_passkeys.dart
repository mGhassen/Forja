import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';

/// Native WebAuthn passkeys for Forja cloud account (Supabase).
///
/// Supported only on macOS and Windows for this slice. Linux, mobile, and TV
/// keep password and/or web login.
class ForjaPasskeys {
  ForjaPasskeys._();

  static final PasskeyAuthenticator authenticator = PasskeyAuthenticator();

  /// True when this build can run a native passkey ceremony.
  static bool get supported {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS || Platform.isWindows;
    } catch (_) {
      return false;
    }
  }
}
