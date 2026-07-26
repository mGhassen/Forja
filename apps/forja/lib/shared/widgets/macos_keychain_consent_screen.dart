import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:rust/rust.dart';

/// Explains macOS Keychain vs local file storage, then persists the choice.
///
/// Shown once before any Keychain I/O. Decline keeps secrets in the app prefs
/// vault (no system password dialog). Accept allows Data Protection Keychain
/// (sandboxed) and one-shot migration of older login-Keychain items.
class MacOsKeychainConsentScreen extends StatelessWidget {
  const MacOsKeychainConsentScreen({super.key, required this.onResolved});

  final VoidCallback onResolved;

  Future<void> _choose(ForjaKeychainConsent choice) async {
    await ForjaPlatformSecureStore.setKeychainConsent(choice);
    onResolved();
  }

  @override
  Widget build(BuildContext context) {
    final body = ColoredBox(
      color: ForjaShellColors.cinematic.menuSurface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Protect account secrets?',
                  style: TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Forja stores login tokens and API keys (account, Trakt, '
                  'Simkl, debrid, IPTV portals, and similar).',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Keychain (recommended)',
                  style: TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Uses the macOS Keychain. After you allow this, macOS may show '
                  'its own password dialog once — it may mention '
                  '"flutter_secure_storage_service". That name is Forja’s '
                  'secure vault, not a separate app. Choose Always Allow if you '
                  'trust Forja.',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Local file storage',
                  style: TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Keeps secrets in Forja’s app data on this Mac. No Keychain '
                  'password prompts. Less protected if someone else can read '
                  'your user files.',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          _choose(ForjaKeychainConsent.declined),
                      child: const Text(
                        'Use local file',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () =>
                          _choose(ForjaKeychainConsent.accepted),
                      style: FilledButton.styleFrom(
                        backgroundColor: ForjaShellColors.brandGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        'Use Keychain',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return DesktopWindowChrome.wrapShell(child: body);
  }
}
