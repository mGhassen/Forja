import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/account/account_rail.dart';
import 'package:forja/features/account/profile_chooser_screen.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/auth/account_vault.dart';
import 'package:forja/shared/sync/providers/account_vault_provider.dart';
import 'package:forja/shared/sync/providers/sync_profiles_provider.dart';
import 'package:forja/shell/brand/forja_profile_avatar.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';

const _profiles = [
  SyncProfile(id: 'p-1', name: 'Alpha', color: '#1ce783', avatarKey: 'forge'),
  SyncProfile(id: 'p-2', name: 'Beta', color: '#1ce783', avatarKey: 'forge'),
];

class _FakeProfiles extends SyncProfilesNotifier {
  @override
  Future<SyncProfilesSnapshot> build() async =>
      const SyncProfilesSnapshot(profiles: _profiles, activeProfileId: 'p-2');
}

class _FakeVault extends AccountVaultNotifier {
  @override
  List<AccountVaultEntry> build() => [
    AccountVaultEntry(
      userId: 'user-a',
      email: 'a@example.test',
      refreshToken: 'rt-a',
      lastUsedAt: DateTime.utc(2026),
    ),
    AccountVaultEntry(
      userId: 'user-b',
      email: 'b@example.test',
      refreshToken: '',
      needsSignIn: true,
      lastUsedAt: DateTime.utc(2026),
    ),
  ];
}

void main() {
  testWidgets(
    'Who’s watching shows the account row, keeps autofocus on the active '
    'profile and offers Add account',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final config = shellPlatformConfigFor(ShellProfile.tv);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncProfilesProvider.overrideWith(_FakeProfiles.new),
            accountVaultProvider.overrideWith(_FakeVault.new),
          ],
          child: MaterialApp(
            builder: (context, child) => ShellScope(
              profile: ShellProfile.tv,
              config: config,
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: config.inputPolicy.wrapAppFocusTraversal,
                child: child!,
              ),
            ),
            home: ProfileChooserScreen(
              useLogoIntroSplash: true,
              onProfileSelected: (_) {},
              onAddAccount: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountRail), findsOneWidget);
      expect(find.text('a@example.test'), findsOneWidget);
      expect(find.text('b@example.test'), findsOneWidget);
      expect(find.text(AccountRail.needsSignInLabel), findsOneWidget);
      expect(find.text('Add account'), findsWidgets);
      expect(find.text('Use another account'), findsNothing);

      // Autofocus stays on the active profile tile, not on the account row.
      final primary = FocusManager.instance.primaryFocus;
      expect(primary, isNotNull);
      final focusedWidget = primary!.context!.widget;
      final betaAvatar = find.byWidgetPredicate(
        (w) => w is ForjaProfileAvatar && w.name == 'Beta',
      );
      expect(betaAvatar, findsOneWidget);
      expect(
        find.descendant(of: find.byWidget(focusedWidget), matching: betaAvatar),
        findsOneWidget,
        reason: 'primary focus should be the active profile tile',
      );
      expect(
        find.descendant(
          of: find.byType(AccountRail),
          matching: find.byWidget(focusedWidget),
        ),
        findsNothing,
      );
    },
  );
}
