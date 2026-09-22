import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/sources/torrent/torrent_sources_panel.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/shell_paint_host.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void main() {
  testWidgets('filterPanelWidthOf never wider than space left of Sources', (
    tester,
  ) async {
    Future<void> expectWidth(double screenW) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(screenW, 800)),
          child: Builder(
            builder: (context) {
              final sources = TorrentSourcesPanel.panelWidthOf(context);
              final filter = TorrentSourcesPanel.filterPanelWidthOf(context);
              expect(filter, lessThanOrEqualTo(screenW - sources));
              expect(filter, greaterThanOrEqualTo(0));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    await expectWidth(1280);
    await expectWidth(900);
    await expectWidth(700);
    await expectWidth(600);
  });

  testWidgets('player side panel width densifies under TV ShellPaintScope', (
    tester,
  ) async {
    late double width;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: shellPaintHostScope(
            inputPolicy: ShellInputPolicy.tv,
            metrics: ShellMetrics.tv,
            child: Builder(
              builder: (context) {
                width = TorrentSourcesPanel.panelWidthOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    expect(width, ShellTokens.playerSidePanelWidthTv);
    expect(width, lessThan(ShellTokens.playerSidePanelWidth));
  });
}
