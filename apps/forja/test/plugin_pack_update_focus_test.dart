import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/plugin_pack_update_dialog.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'plugin pack update overlay claims focus from background poster',
    (tester) async {
      final background = FocusNode(debugLabel: 'home-poster');

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        ignoring: true,
                        child: ExcludeFocus(
                          excluding: true,
                          child: FocusableControl(
                            focusNode: background,
                            autoFocus: true,
                            scaleOnFocus: 1.0,
                            onTap: () {},
                            child: const SizedBox(width: 120, height: 180),
                          ),
                        ),
                      ),
                      PluginPackUpdateOverlay(
                        updates: const [
                          EnginePackUpdateInfo(
                            sourceUrl: 'https://example.test/pack',
                            packName: 'Test Pack',
                            installedVersion: '1.0.0',
                            remoteVersion: '1.0.1',
                          ),
                        ],
                        onDismiss: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Claim retries across a few frames (shell reclaim class).
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      expect(background.hasPrimaryFocus, isFalse);
      expect(find.text('Update'), findsOneWidget);

      final confirm = FocusManager.instance.primaryFocus;
      expect(confirm, isNotNull);
      expect(confirm!.debugLabel, 'plugin-update-confirm');

      background.dispose();
    },
  );

  testWidgets(
    'plugin pack update host restores prior focus after cancel',
    (tester) async {
      final prior = FocusNode(debugLabel: 'prior-control');
      addTearDown(prior.dispose);

      late StateSetter hostSetState;
      List<EnginePackUpdateInfo>? updates;
      FocusNode? returnFocus;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      hostSetState = setState;
                      final open = updates != null;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          IgnorePointer(
                            ignoring: open,
                            child: ExcludeFocus(
                              excluding: open,
                              child: FocusableControl(
                                focusNode: prior,
                                autoFocus: true,
                                scaleOnFocus: 1.0,
                                onTap: () {},
                                child: const SizedBox(width: 80, height: 80),
                              ),
                            ),
                          ),
                          if (updates != null)
                            Positioned.fill(
                              child: PluginPackUpdateOverlay(
                                updates: updates!,
                                onDismiss: () {
                                  final back = returnFocus;
                                  returnFocus = null;
                                  hostSetState(() => updates = null);
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (back != null && back.canRequestFocus) {
                                      back.requestFocus();
                                    }
                                  });
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(prior.hasPrimaryFocus, isTrue);

      returnFocus = FocusManager.instance.primaryFocus;
      hostSetState(() {
        updates = const [
          EnginePackUpdateInfo(
            sourceUrl: 'https://example.test/pack',
            packName: 'Test Pack',
            installedVersion: '1.0.0',
            remoteVersion: '1.0.1',
          ),
        ];
      });
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(prior.hasPrimaryFocus, isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();

      expect(prior.hasPrimaryFocus, isTrue);
    },
  );
}
