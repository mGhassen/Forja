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

  test('ShellTokens maxMountedTabs is defined', () {
    expect(ShellTokens.maxMountedTabs, greaterThanOrEqualTo(3));
    expect(ShellTokens.tabStaleDefault.inMinutes, 15);
  });
}
