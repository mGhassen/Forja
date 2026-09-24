import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/sources/torrent/torrent_source_tiles.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';

/// Guards Live Sports Providers: tiles in an unbounded ListView must layout
/// (Row.stretch on the probe rail forced infinite height — issue 370).
void main() {
  testWidgets('SourcesPanelChannelTile lays out inside ListView', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: ShellScope(
            profile: ShellProfile.desktop,
            config: shellPlatformConfigFor(ShellProfile.desktop),
            child: Scaffold(
              body: ListView(
                children: [
                  SourcesPanelChannelTile(
                    title: 'HD · Mirror 1',
                    provider: 'PPV',
                    viewerCount: 1200,
                    badges: const ['HD'],
                    onPlay: () {},
                  ),
                  SourcesPanelChannelTile(
                    title: 'SD · Mirror 2',
                    provider: 'Streamed',
                    onPlay: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('HD · Mirror 1'), findsOneWidget);
    expect(find.text('SD · Mirror 2'), findsOneWidget);
  });
}
