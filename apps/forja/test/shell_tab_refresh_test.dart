import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

class _StaleProbe extends StatefulWidget {
  const _StaleProbe();

  @override
  State<_StaleProbe> createState() => _StaleProbeState();
}

class _StaleProbeState extends State<_StaleProbe> with ShellTabRefresh<_StaleProbe> {
  int refreshCount = 0;

  @override
  Duration get shellStaleAfter => const Duration(milliseconds: 50);

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    refreshCount++;
  }

  @override
  bool get shellBlocksEviction => true;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _EvictProbe extends StatefulWidget {
  const _EvictProbe();

  @override
  State<_EvictProbe> createState() => _EvictProbeState();
}

class _EvictProbeState extends State<_EvictProbe> with ShellTabRefresh<_EvictProbe> {
  @override
  Future<void> onShellTabRefresh({required bool force}) async {}

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('ShellTabRefresh force bypasses TTL', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _StaleProbe()));
    final state = tester.state<_StaleProbeState>(find.byType(_StaleProbe));

    await state.refreshIfStale();
    await state.refreshIfStale(force: true);
    expect(state.refreshCount, 2);
  });

  test('ShellTokens maxMountedTabs is platform-aware', () {
    expect(ShellTokens.maxMountedTabsDesktop, 5);
    expect(ShellTokens.maxMountedTabsTv, 3);
    expect(ShellTokens.maxMountedTabs, greaterThanOrEqualTo(3));
    expect(ShellTokens.tabStaleDefault.inMinutes, 15);
    expect(ShellTokens.tabStaleIptv.inMinutes, 10);
  });

  testWidgets('ShellTabRefresh shellBlocksEviction defaults false', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _EvictProbe()));
    final state = tester.state<_EvictProbeState>(find.byType(_EvictProbe));
    expect(state.shellBlocksEviction, isFalse);
  });

  testWidgets('ShellTabRefresh shellBlocksEviction can override', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _StaleProbe()));
    final state = tester.state<_StaleProbeState>(find.byType(_StaleProbe));
    expect(state.shellBlocksEviction, isTrue);
  });

  testWidgets('ShellTabRefresh hide/show toggles shellTabVisible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _EvictProbe()));
    final state = tester.state<_EvictProbeState>(find.byType(_EvictProbe));
    expect(state.shellTabVisible, isTrue);
    state.onShellTabHidden();
    expect(state.shellTabVisible, isFalse);
    state.onShellTabShown();
    expect(state.shellTabVisible, isTrue);
  });
}
