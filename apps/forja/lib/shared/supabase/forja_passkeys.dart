import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/exceptions.dart';

/// Native WebAuthn passkeys for Forja cloud account (Supabase).
///
/// macOS + Windows show the UI. Native macOS needs Associated Domains
/// (`webcredentials:www.forjahq.xyz`), which requires a paid Apple Developer
/// team to sign — Personal Team builds omit that entitlement, so the button
/// may fail with a domain-association error until a paid team is used.
/// Linux / mobile / TV: no native passkeys.
class ForjaPasskeys {
  ForjaPasskeys._();

  /// Kill switch for passkey buttons / manage UI. Keep implementation; flip to
  /// `true` when native Associated Domains (or Windows) are ready again.
  static const bool uiEnabled = false;

  /// Shared authenticator. Debug builds enable Corbado doctor diagnostics.
  static final PasskeyAuthenticator authenticator = PasskeyAuthenticator(
    debugMode: kDebugMode,
  );

  /// True when this build should expose passkey UI and run a ceremony.
  static bool get supported {
    if (!uiEnabled) return false;
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS || Platform.isWindows;
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
