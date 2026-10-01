import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/episode_range_bar.dart';
import 'package:forja_foundation/widgets/details/tv_season_episode_picker.dart';

Widget _wrap({required bool tv, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        usesTvDensity: tv,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(body: child),
      ),
    ),
  );
}

TvSeasonEpisodePicker _picker({
  String episodeView = kEpisodeViewCards,
  Set<String> watchedEpisodes = const {},
}) {
  return TvSeasonEpisodePicker(
    tmdbId: 1,
    seasonCount: 1,
    selectedSeason: 1,
    selectedEpisode: 1,
    isLoadingSeason: false,
    seasonData: {
      'episodes': [
        for (var i = 1; i <= 3; i++)
          {
            'episode_number': i,
            'name': 'Episode $i',
            'overview': 'Overview $i',
            'still_path': '',
          },
      ],
    },
    watchedEpisodes: watchedEpisodes,
    fallbackPosterPath: '',
    onSeasonSelected: (_) {},
    onEpisodeSelected: (_) {},
    onToggleWatched: (_, _) {},
    episodeView: episodeView,
  );
}

void main() {
  testWidgets('Episodes title uses leanback type under usesTvDensity', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(tv: false, child: _picker()));
    final desk = tester.widget<Text>(find.text('Episodes'));
    expect(desk.style?.fontSize, ShellTokens.sectionTitleFontSize);

    await tester.pumpWidget(_wrap(tv: true, child: _picker()));
    final tv = tester.widget<Text>(find.text('Episodes'));
    expect(tv.style?.fontSize, ShellTokens.tvTitleFontSize);

    final count = tester.widget<Text>(find.text('3'));
    expect(count.style?.fontSize, ShellTokens.tvTypeSize(14));
  });

  testWidgets('Number chips view paints episode numbers', (tester) async {
    await tester.pumpWidget(
      _wrap(tv: false, child: _picker(episodeView: kEpisodeViewChips)),
    );
    expect(find.text('1'), findsWidgets); // count row + chip
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Episode 1'), findsNothing);
  });

  testWidgets('Number chips show a corner watched badge', (tester) async {
    await tester.pumpWidget(
      _wrap(
        tv: false,
        child: _picker(
          episodeView: kEpisodeViewChips,
          watchedEpisodes: const {'1_S1_E2'},
        ),
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
