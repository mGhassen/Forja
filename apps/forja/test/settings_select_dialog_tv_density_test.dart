import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void main() {
  setUpAll(installShellPaintHostAdapters);

  testWidgets('Settings select dialog uses TV type ladder under ShellScope.tv', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: ShellScope(
            profile: ShellProfile.tv,
            config: shellPlatformConfigFor(ShellProfile.tv),
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      showSettingsSelectDialog(
                        context: context,
                        title: 'IPTV engine',
                        value: 'ExoPlayer (Media3)',
                        options: const [
                          'ExoPlayer (Media3)',
                          'MediaKit (libmpv)',
                        ],
                      );
                    },
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('IPTV engine'));
    expect(title.style?.fontSize, ShellTokens.tvTitleFontSize);
    expect(title.style?.fontSize, SettingsTokens.pageTitleSizeTv);

    final option = tester.widget<Text>(find.text('ExoPlayer (Media3)').first);
    expect(option.style?.fontSize, ShellTokens.tvBodyFontSize);
  });
}
