import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';

/// Explains macOS Keychain vs local file, then persists the choice.
///
/// Not shown at boot. Default is local file (no Keychain). Call this only when
/// the user opts into Keychain (e.g. Settings → Privacy).
Future<ForjaKeychainConsent?> showMacOsKeychainConsentDialog(
  BuildContext context,
) async {
  if (!Platform.isMacOS) return null;
  return showDialog<ForjaKeychainConsent>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ShellScope.rehost(context, const _MacOsKeychainConsentDialog()),
  );
}

class _MacOsKeychainConsentDialog extends StatelessWidget {
  const _MacOsKeychainConsentDialog();

  static const _plain = TextStyle(decoration: TextDecoration.none);

  Future<void> _choose(BuildContext context, ForjaKeychainConsent choice) async {
    await ForjaPlatformSecureStore.setKeychainConsent(choice);
    if (context.mounted) Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: const Text(
        'Use macOS Keychain?',
        style: TextStyle(
          color: ForjaShellColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
      content: DefaultTextStyle.merge(
        style: _plain,
        child: const SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forja can store login tokens and API keys in the macOS '
                'Keychain instead of a local app file.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'After you allow this, macOS may show its own password dialog '
                'once — it may mention "flutter_secure_storage_service". That '
                'name is Forja’s secure vault, not a separate app. Choose '
                'Always Allow if you trust Forja.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'You can keep using local file storage (default) with no '
                'Keychain prompts.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _choose(context, ForjaKeychainConsent.declined),
          child: const Text(
            'Keep local file',
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => _choose(context, ForjaKeychainConsent.accepted),
          style: FilledButton.styleFrom(
            backgroundColor: ForjaShellColors.brandGreen,
            foregroundColor: Colors.black,
          ),
          child: const Text(
            'Use Keychain',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
