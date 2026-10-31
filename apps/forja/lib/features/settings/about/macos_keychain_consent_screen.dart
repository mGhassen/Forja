import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

/// Explains macOS Keychain vs local file, then persists the choice.
///
/// Not shown at boot. Default is local file (no Keychain). Call this only when
/// the user opts into Keychain (Settings → About).
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
      title: Text(
        context.l10n.aboutKeychainConsentTitle,
        style: TextStyle(
          color: ForjaShellColors.textPrimary,
          fontSize: SettingsTokens.typeSizeOf(context, 18),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
      content: DefaultTextStyle.merge(
        style: _plain,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.aboutKeychainConsentBodyStore,
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: SettingsTokens.typeSizeOf(context, 14),
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 12),
              Text(
                context.l10n.aboutKeychainConsentBodyPrompt,
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: SettingsTokens.typeSizeOf(context, 14),
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 12),
              Text(
                context.l10n.aboutKeychainConsentBodyLocal,
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: SettingsTokens.typeSizeOf(context, 14),
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
          child: Text(
            context.l10n.aboutKeychainConsentKeepLocal,
            style: const TextStyle(
              color: ForjaShellColors.textSecondary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Button(
          variant: ButtonVariant.primary,
          label: context.l10n.aboutKeychainConsentUseKeychain,
          onPressed: () => _choose(context, ForjaKeychainConsent.accepted),
        ),
      ],
    );
  }
}
