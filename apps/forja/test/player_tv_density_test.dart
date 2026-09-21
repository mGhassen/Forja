import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/shell_paint_host.dart';
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
      ShellTokens.playerChromeTitleFontSizeTv,
      ShellTokens.tvTitleFontSize,
    );
    expect(
      ShellTokens.playerChromeTimeFontSizeTv,
      ShellTokens.tvMetaFontSize,
    );
  });
}
