import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';

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
}
