import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void main() {
  testWidgets('player popup type densifies under TV ShellPaintScope', (tester) async {
    late double title;
    late double option;
    late double padV;
    await tester.pumpWidget(
      MaterialApp(
        home: shellPaintHostScope(
          inputPolicy: ShellInputPolicy.tv,
          metrics: ShellMetrics.tv,
          child: Builder(
            builder: (context) {
              title = PlayerPopupTokens.titleFontSizeOf(context);
              option = PlayerPopupTokens.optionFontSizeOf(context);
              padV = PlayerPopupTokens.selectCardPaddingOf(context).vertical;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(title, ShellTokens.tvTitleFontSize);
    expect(option, ShellTokens.tvBodyFontSize);
    expect(padV, lessThan(PlayerPopupTokens.selectCardPadding.vertical));
  });

  test('player chrome tokens denser on TV', () {
    expect(
      ShellTokens.playerChromeBtnSizeTv,
      lessThan(ShellTokens.playerChromeBtnSize),
    );
    expect(
      ShellTokens.playerChromePlayBtnSizeTv,
      lessThan(ShellTokens.playerChromePlayBtnSize),
    );
    expect(
      ShellTokens.playerChromeRoundBtnSizeTv,
      lessThan(ShellTokens.playerChromeRoundBtnSize),
    );
    expect(
      ShellTokens.playerChromeTitleFontSizeTv,
      ShellTokens.tvTitleFontSize,
    );
    expect(
      ShellTokens.playerChromeTimeFontSizeTv,
      ShellTokens.tvMetaFontSize,
    );
  });

  test('player popup check icon densifies on TV', () {
    expect(
      PlayerPopupTokens.checkIconSizeTv,
      lessThan(PlayerPopupTokens.checkIconSize),
    );
    expect(
      PlayerPopupTokens.checkIconSizeTv,
      PlayerPopupTokens.checkIconSize * ShellTokens.tvChromeScale,
    );
  });

  testWidgets(
    'TV option chips keep equal height with and without check',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShellScope(
            profile: ShellProfile.tv,
            config: shellPlatformConfigFor(ShellProfile.tv),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerPopupOptionChip(
                        key: const Key('idle'),
                        label: 'ExoPlayer (Media3)',
                        selected: false,
                        expanded: true,
                        onTap: () {},
                      ),
                      PlayerPopupOptionChip(
                        key: const Key('selected'),
                        label: 'MediaKit (libmpv)',
                        selected: true,
                        expanded: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final idle = tester.getSize(find.byKey(const Key('idle')));
      final selected = tester.getSize(find.byKey(const Key('selected')));
      expect(selected.height, idle.height);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_rounded)).size,
        PlayerPopupTokens.checkIconSizeTv,
      );
    },
  );

  testWidgets('player flat icon densifies under TV ShellPaintScope', (
    tester,
  ) async {
    late double paintedSize;
    await tester.pumpWidget(
      MaterialApp(
        home: shellPaintHostScope(
          inputPolicy: ShellInputPolicy.tv,
          metrics: ShellMetrics.tv,
          child: Builder(
            builder: (context) {
              paintedSize = playerChromeScale(
                context,
                ShellTokens.playerChromeBtnSize,
              );
              return PlayerFlatIconButton(
                icon: Icons.play_arrow_rounded,
                size: ShellTokens.playerChromeBtnSize,
                iconSize: ShellTokens.playerChromeIconSize,
                onPressed: () {},
              );
            },
          ),
        ),
      ),
    );
    expect(paintedSize, ShellTokens.playerChromeBtnSizeTv);
    expect(paintedSize, lessThan(ShellTokens.playerChromeBtnSize));
  });

  testWidgets('player Source text button densifies under TV ShellPaintScope', (
    tester,
  ) async {
    late double maxW;
    late double typeFs;
    await tester.pumpWidget(
      MaterialApp(
        home: shellPaintHostScope(
          inputPolicy: ShellInputPolicy.tv,
          metrics: ShellMetrics.tv,
          child: Builder(
            builder: (context) {
              maxW = playerChromeScale(context, 148);
              typeFs = playerChromeTypeSize(context, 12);
              return PlayerStreamPickerButton(
                label: 'Videasy',
                server: 'Yoru',
                size: ShellTokens.playerChromeBtnSize,
                iconSize: ShellTokens.playerChromeIconSize,
                onPressedWithContext: (_) {},
              );
            },
          ),
        ),
      ),
    );
    expect(maxW, 148 * ShellTokens.tvChromeScale);
    expect(maxW, lessThan(148));
    expect(typeFs, ShellTokens.tvBodyFontSize);
    expect(
      tester.widget<Text>(find.text('Videasy')).style!.fontSize,
      ShellTokens.tvMetaFontSize,
    );
    expect(
      tester.widget<Text>(find.text('Yoru')).style!.fontSize,
      ShellTokens.tvMetaFontSize,
    );
  });

  testWidgets('player top-bar buttons densify under TV ShellPaintScope', (
    tester,
  ) async {
    late double painted;
    await tester.pumpWidget(
      MaterialApp(
        home: shellPaintHostScope(
          inputPolicy: ShellInputPolicy.tv,
          metrics: ShellMetrics.tv,
          child: Builder(
            builder: (context) {
              painted = playerChromeScale(
                context,
                ShellTokens.playerChromeTopBtnSize,
              );
              return Scaffold(
                body: PlayerTopBar(
                  title: 'Title',
                  onBack: () {},
                  trailing: PlayerTopBarActions(
                    showPlayer: true,
                    onPlayer: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(painted, ShellTokens.playerChromeTopBtnSizeTv);
    expect(painted, lessThan(ShellTokens.playerChromeTopBtnSize));
    final buttons = find.byType(PlayerFlatIconButton);
    expect(buttons, findsNWidgets(2));
    expect(tester.getSize(buttons.at(0)).width, painted);
    expect(tester.getSize(buttons.at(1)).width, painted);
  });

  testWidgets('trailer chrome card lengths densify under TV ShellPaintScope', (
    tester,
  ) async {
    late double cardW;
    late double pad;
    await tester.pumpWidget(
      MaterialApp(
        home: shellPaintHostScope(
          inputPolicy: ShellInputPolicy.tv,
          metrics: ShellMetrics.tv,
          child: Builder(
            builder: (context) {
              cardW = playerChromeScale(context, 280);
              pad = playerChromeScale(context, 16);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(cardW, closeTo(280 * ShellTokens.tvChromeScale, 0.001));
    expect(pad, closeTo(16 * ShellTokens.tvChromeScale, 0.001));
    expect(cardW, lessThan(280));
  });
}
