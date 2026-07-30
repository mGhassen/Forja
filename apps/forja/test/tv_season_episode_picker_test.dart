import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';

Widget _wrapTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: Scaffold(body: child),
      ),
    ),
  );
}

TvSeasonEpisodePicker _picker({
  required int selectedEpisode,
  required ValueChanged<int> onEpisodeSelected,
  required ValueChanged<int> onEpisodePlay,
}) {
  return TvSeasonEpisodePicker(
    tmdbId: 1,
    seasonCount: 1,
    selectedSeason: 1,
    selectedEpisode: selectedEpisode,
    isLoadingSeason: false,
    seasonData: {
      'episodes': [
        {'episode_number': 1, 'name': 'Pilot'},
        {'episode_number': 2, 'name': 'Second'},
      ],
    },
    watchedEpisodes: const {},
    fallbackPosterPath: '',
    onSeasonSelected: (_) {},
    onEpisodeSelected: onEpisodeSelected,
    onEpisodePlay: onEpisodePlay,
    onToggleWatched: (_, _) {},
  );
}

void main() {
  testWidgets('TV: card OK selects and arms; play icon OK plays', (
    tester,
  ) async {
    var selected = 1;
    var playCount = 0;

    await tester.pumpWidget(
      _wrapTv(
        _picker(
          selectedEpisode: selected,
          onEpisodeSelected: (ep) => selected = ep,
          onEpisodePlay: (_) => playCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ep-1-2')));
    await tester.pump();
    expect(selected, 2);
    expect(playCount, 0);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ep-1-2')),
        matching: find.byKey(const ValueKey('shell-card-play-hover-target')),
      ),
    );
    await tester.pump();
    expect(playCount, 1);
  });

  testWidgets('TV: resume episode is armed on open; play icon plays it', (
    tester,
  ) async {
    var playCount = 0;
    await tester.pumpWidget(
      _wrapTv(
        _picker(
          selectedEpisode: 2,
          onEpisodeSelected: (_) {},
          onEpisodePlay: (_) => playCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ep-1-2')),
        matching: find.byKey(const ValueKey('shell-card-play-hover-target')),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ep-1-2')),
        matching: find.byKey(const ValueKey('shell-card-play-hover-target')),
      ),
    );
    await tester.pump();
    expect(playCount, 1);
  });
}
