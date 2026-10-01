import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/sources/torrent/torrent_source_filters.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

Widget _harness({
  required ShellProfile profile,
  required Widget child,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: profile == ShellProfile.tv
            ? const Size(1920, 1080)
            : const Size(1280, 800),
      ),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
}

TorrentSourceSearchToolbar _toolbar() {
  return TorrentSourceSearchToolbar(
    searchQuery: '',
    onSearchChanged: (_) {},
    availableQualities: const {},
    availableLanguages: const {},
    availableTech: const {},
    activeQualityFilters: const {},
    activeLanguageFilters: const {},
    activeTechFilters: const {},
    onQualityFiltersChanged: (_) {},
    onLanguageFiltersChanged: (_) {},
    onTechFiltersChanged: (_) {},
    showFilters: true,
  );
}

void main() {
  testWidgets('desktop Sources search face is controlHeight (not isDense collapse)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(profile: ShellProfile.desktop, child: _toolbar()),
    );
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('sources-panel-search'));
    expect(search, findsOneWidget);
    final box = tester.renderObject<RenderBox>(search);
    expect(box.size.height, ShellTokens.torrentPanelSearchHeight);
    expect(box.size.height, ShellTokens.controlHeight);
    // Guard against the old ~22px isDense collapse.
    expect(box.size.height, greaterThanOrEqualTo(36));
  });

  testWidgets('TV Sources search face uses leanback control height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(profile: ShellProfile.tv, child: _toolbar()),
    );
    await tester.pumpAndSettle();

    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('sources-panel-search')),
    );
    expect(box.size.height, ShellTokens.torrentPanelSearchHeightTv);
    expect(box.size.height, ShellTokens.controlHeightTv);
  });
}
