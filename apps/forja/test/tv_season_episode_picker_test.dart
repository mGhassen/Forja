import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
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
  testWidgets('TV: default-selected ep1 does not play on first tap', (
    tester,
  ) async {
    var playCount = 0;
    await tester.pumpWidget(
      _wrapTv(
        _picker(
          selectedEpisode: 1,
          onEpisodeSelected: (_) {},
          onEpisodePlay: (_) => playCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ep-1-1')));
    await tester.pump();
    expect(playCount, 0);
  });

  testWidgets('TV: first tap selects, second tap on same card plays', (
    tester,
  ) async {
    var selected = 1;
    var playCount = 0;

    Future<void> pumpPicker() async {
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
    }

    await pumpPicker();

    await tester.tap(find.byKey(const ValueKey('ep-1-2')));
    await tester.pump();
    expect(selected, 2);
    expect(playCount, 0);

    await tester.tap(find.byKey(const ValueKey('ep-1-2')));
    await tester.pump();
    expect(playCount, 1);
  });
}
