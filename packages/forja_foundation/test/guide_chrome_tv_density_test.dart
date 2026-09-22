import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:forja_foundation/widgets/guide/channel_guide_panel.dart';
import 'package:forja_foundation/widgets/guide/channel_search_overlay.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_card.dart';

Widget _tvScope({required Widget child}) {
  return ShellPaintScope(
    useTvFocus: true,
    scaleOnHover: false,
    focusStyled: (_, {required focused}) => focused,
    usesTvDensity: true,
    child: child,
  );
}

ChannelGuide _searchGuide({int channelCount = 12}) {
  return ChannelGuide(
    groups: const [GuideGroup(id: 'g', name: 'EU | FR | GÉNÉRAL')],
    channels: [
      for (var i = 0; i < channelCount; i++)
        GuideChannel(
          id: 'c$i',
          name: 'FR - M6 $i',
          groupId: 'g',
        ),
    ],
    initialChannelId: 'c0',
    initialGroupId: 'g',
  );
}

void main() {
  testWidgets('guide chrome lengths densify under TV ShellPaintScope', (
    tester,
  ) async {
    late double panelW;
    late double peekW;
    late double epgH;
    late double typeFs;
    late double floatingW;
    late double channelExtent;
    await tester.pumpWidget(
      MaterialApp(
        home: _tvScope(
          child: Builder(
            builder: (context) {
              panelW = ChannelGuidePanel.panelWidthFor(context, wide: true);
              peekW = ChannelGuidePanel.epgPeekWidthOf(context);
              epgH = GuideChromeStyle.len(context, kGuideEpgCardHeight);
              typeFs = GuideChromeStyle.type(context, 16);
              floatingW = GuideChromeStyle.floatingEpgMaxWidthOf(
                context,
                compact: false,
              );
              channelExtent = ChannelGuidePanel.channelExtentOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(panelW, ChannelGuidePanel.panelWidthWide * ShellTokens.tvChromeScale);
    expect(peekW, ChannelGuidePanel.epgPeekWidth * ShellTokens.tvChromeScale);
    expect(epgH, kGuideEpgCardHeight * ShellTokens.tvChromeScale);
    expect(typeFs, ShellTokens.tvTitleFontSize);
    expect(
      floatingW,
      GuideChromeStyle.floatingEpgMaxWidth * ShellTokens.tvChromeScale,
    );
    expect(
      channelExtent,
      ChannelGuidePanel.channelRowExtent * ShellTokens.tvChromeScale,
    );
    expect(floatingW, lessThan(GuideChromeStyle.floatingEpgMaxWidth));
    expect(panelW, lessThan(ChannelGuidePanel.panelWidthWide));
  });

  testWidgets('guide chrome stays desktop without TV density', (tester) async {
    late double panelW;
    late double floatingW;
    late double channelExtent;
    await tester.pumpWidget(
      MaterialApp(
        home: ShellPaintScope(
          useTvFocus: false,
          scaleOnHover: true,
          focusStyled: (_, {required focused}) => focused,
          usesTvDensity: false,
          child: Builder(
            builder: (context) {
              panelW = ChannelGuidePanel.panelWidthFor(context, wide: true);
              floatingW = GuideChromeStyle.floatingEpgMaxWidthOf(
                context,
                compact: false,
              );
              channelExtent = ChannelGuidePanel.channelExtentOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(panelW, ChannelGuidePanel.panelWidthWide);
    expect(floatingW, GuideChromeStyle.floatingEpgMaxWidth);
    expect(channelExtent, ChannelGuidePanel.channelRowExtent);
  });

  testWidgets('channel search overlay fits short TV viewport', (tester) async {
    // Landscape phone / short leanback window — header + 8 rows used to overflow.
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    FlutterErrorDetails? overflow;
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('OVERFLOWED')) {
        overflow = details;
      }
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _tvScope(
            child: ChannelSearchOverlay(
              guide: _searchGuide(),
              currentChannelId: 'c0',
              onChannelSelected: (_) {},
              onClose: () {},
              // Density comes from ShellPaintScope; keep the field editable so
              // enterText can populate results without TV browse/IME activate.
              isTv: false,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'm6');
    await tester.pumpAndSettle();

    expect(overflow, isNull);
    expect(find.textContaining('OVERFLOWED'), findsNothing);
    expect(find.textContaining('FR - M6'), findsWidgets);

    final panel = tester.getSize(find.byType(ClipRRect).first);
    expect(panel.height, lessThanOrEqualTo(360));
  });
}
