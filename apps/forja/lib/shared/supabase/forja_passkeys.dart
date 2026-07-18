import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/exceptions.dart';

/// Native WebAuthn passkeys for Forja cloud account (Supabase).
///
/// **Windows:** native passkeys via Windows Hello.
/// **macOS:** native passkeys need Associated Domains (`webcredentials:`), which
/// Apple only allows on a paid Developer Program team — not Personal Team.
/// Until that entitlement is restored under a paid team, macOS uses password /
/// Web login (passkeys still work on the website).
/// Linux / mobile / TV: no native passkeys.
class ForjaPasskeys {
  ForjaPasskeys._();

  /// Shared authenticator. Debug builds enable Corbado doctor diagnostics.
  static final PasskeyAuthenticator authenticator = PasskeyAuthenticator(
    debugMode: kDebugMode,
  );

  /// True when this build can run a native passkey ceremony.
  static bool get supported {
    if (kIsWeb) return false;
    try {
      // macOS omitted: Personal Team cannot sign Associated Domains.
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  /// Maps platform / WebAuthn failures to a short user-facing message.
  static String userMessage(Object error) {
    if (error is PasskeyAuthCancelledException) {
      return 'Passkey sign-in was cancelled.';
    }
    if (error is NoCredentialsAvailableException) {
      return 'No passkey found on this device. Add one on the web under Account, or use password.';
    }
    if (error is DomainNotAssociatedException) {
      final detail = error.message?.trim();
      if (detail != null && detail.isNotEmpty) {
        return detail;
      }
      return 'This app is not linked to www.forjahq.xyz for passkeys yet. '
          'Use password or web login, or rebuild after Associated Domains are live.';
    }
    if (error is DeviceNotSupportedException) {
      return 'This device does not support passkeys.';
    }
    if (error is TimeoutException) {
      return 'Passkey timed out. Try again.';
    }
    if (error is UnhandledAuthenticatorException) {
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Passkey authenticator failed (${error.code}).';
    }
    final text = error.toString().trim();
    if (text.isNotEmpty && text != 'Exception' && text != 'Instance of \'Exception\'') {
      // Prefer the message after "Exception: " / "Error: " when present.
      final match = RegExp(r'^(?:Exception|Error):\s*(.+)$').firstMatch(text);
      return match?.group(1)?.trim() ?? text;
    }
    return 'Passkey sign-in failed. Try again, or use password.';
  }
}
