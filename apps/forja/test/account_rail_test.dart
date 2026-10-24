import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/account/account_rail.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';

const _accounts = [
  AccountRailItem(userId: 'user-a', label: 'a@example.test'),
  AccountRailItem(userId: 'user-b', label: 'b@example.test'),
  AccountRailItem(userId: 'user-c', label: 'c@example.test', needsSignIn: true),
];

Widget _tvApp(Widget child) {
  final config = shellPlatformConfigFor(ShellProfile.tv);
  return MaterialApp(
    builder: (context, inner) => ShellScope(
      profile: ShellProfile.tv,
      config: config,
      child: ShellInputPolicy.maybeWrapFocusTraversal(
        enabled: config.inputPolicy.wrapAppFocusTraversal,
        child: inner!,
      ),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('renders every account, marks the active one and needsSignIn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _tvApp(
        AccountRail(
          accounts: _accounts,
          activeUserId: 'user-a',
          onSwitch: (_) {},
          onAdd: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('a@example.test'), findsOneWidget);
    expect(find.text('b@example.test'), findsOneWidget);
    expect(find.text('c@example.test'), findsOneWidget);
    expect(find.text(AccountRail.activeLabel), findsOneWidget);
    expect(find.text(AccountRail.needsSignInLabel), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });

  testWidgets('D-pad focus only highlights; OK fires onSwitch', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final switched = <String>[];
    await tester.pumpWidget(
      _tvApp(
        AccountRail(
          accounts: _accounts,
          activeUserId: 'user-a',
          onSwitch: switched.add,
          onAdd: () {},
        ),
      ),
    );
    await tester.pump();

    final chipB = find.byKey(const ValueKey('account-chip-user-b'));
    expect(chipB, findsOneWidget);
    final node = Focus.of(
      tester.element(
        find.descendant(of: chipB, matching: find.byType(Text)).first,
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isTrue);
    expect(switched, isEmpty, reason: 'focus alone must not switch');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(switched, ['user-b']);

    // Enter on another chip (activation coalesce is per chip, wall clock).
    final chipC = find.byKey(const ValueKey('account-chip-user-c'));
    final nodeC = Focus.of(
      tester.element(
        find.descendant(of: chipC, matching: find.byType(Text)).first,
      ),
    );
    nodeC.requestFocus();
    await tester.pump();
    expect(switched, ['user-b'], reason: 'focus alone must not switch');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(switched, ['user-b', 'user-c']);
  });

  testWidgets('managing mode: chips say remove and OK fires onRemove', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final removed = <String>[];
    final switched = <String>[];
    await tester.pumpWidget(
      _tvApp(
        AccountRail(
          accounts: _accounts,
          activeUserId: 'user-a',
          managing: true,
          onSwitch: switched.add,
          onRemove: removed.add,
          onAdd: () {},
        ),
      ),
    );
    await tester.pump();

    // The active account keeps its "Active" label: it is signed out, not
    // removed, so no Remove affordance.
    expect(find.text(AccountRail.removeLabel), findsNWidgets(2));
    expect(find.text(AccountRail.activeLabel), findsOneWidget);
    expect(find.text('Add account'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('account-chip-user-a')));
    await tester.pump();
    expect(removed, isEmpty);

    await tester.tap(find.byKey(const ValueKey('account-chip-user-c')));
    await tester.pump();
    expect(removed, ['user-c']);
    expect(switched, isEmpty);
  });
}
