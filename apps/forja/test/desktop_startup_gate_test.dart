import 'package:flutter_test/flutter_test.dart';
import 'package:forja/app/desktop_startup_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('resolveDesktopStartupDestination', () {
    test('shows account entry for configured signed-out desktop', () {
      expect(
        resolveDesktopStartupDestination(
          isDesktop: true,
          supabaseConfigured: true,
          hasSession: false,
        ),
        DesktopStartupDestination.account,
      );
    });

    test('restored desktop session goes directly to splash', () {
      expect(
        resolveDesktopStartupDestination(
          isDesktop: true,
          supabaseConfigured: true,
          hasSession: true,
        ),
        DesktopStartupDestination.splash,
      );
    });

    test('unconfigured desktop preserves splash-first startup', () {
      expect(
        resolveDesktopStartupDestination(
          isDesktop: true,
          supabaseConfigured: false,
          hasSession: false,
        ),
        DesktopStartupDestination.splash,
      );
    });

    test('non-desktop platforms preserve splash-first startup', () {
      expect(
        resolveDesktopStartupDestination(
          isDesktop: false,
          supabaseConfigured: true,
          hasSession: false,
        ),
        DesktopStartupDestination.splash,
      );
    });
  });

  group('shouldReturnToAccountOnSignOut', () {
    test('user-initiated always returns to account', () {
      expect(
        shouldReturnToAccountOnSignOut(
          reason: SignOutReason.userInitiated,
          inActiveAppShell: true,
        ),
        isTrue,
      );
      expect(
        shouldReturnToAccountOnSignOut(
          reason: SignOutReason.userInitiated,
          inActiveAppShell: false,
        ),
        isTrue,
      );
    });

    test('expired session keeps shell while app is running', () {
      expect(
        shouldReturnToAccountOnSignOut(
          reason: SignOutReason.sessionExpired,
          inActiveAppShell: true,
        ),
        isFalse,
      );
    });

    test('missing session keeps shell while app is running', () {
      expect(
        shouldReturnToAccountOnSignOut(
          reason: SignOutReason.sessionMissing,
          inActiveAppShell: true,
        ),
        isFalse,
      );
    });

    test('involuntary loss before shell still returns to account', () {
      expect(
        shouldReturnToAccountOnSignOut(
          reason: SignOutReason.sessionExpired,
          inActiveAppShell: false,
        ),
        isTrue,
      );
    });
  });
}
