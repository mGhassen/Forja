import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/movie_poster_card.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

Widget _wrapProfile({
  required ShellProfile profile,
  required Widget child,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: child,
      ),
    ),
  );
}

Movie _testMovie() => Movie(
      id: 1,
      title: 'Test',
      posterPath: '',
      backdropPath: '',
      voteAverage: 0,
      releaseDate: '2024',
      overview: '',
      mediaType: 'movie',
    );

void main() {
  testWidgets('shellUsesWideLayout is true for tv profile on phone-sized width',
      (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: Builder(
          builder: (context) {
            expect(shellUsesWideLayout(context), isTrue);
            expect(shellMovieCardWidth(context), 90);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('MoviePosterCard uses FocusableControl on tv profile', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: MoviePosterCard(movie: _testMovie(), onTap: () {}),
      ),
    );
    expect(find.byType(FocusableControl), findsAtLeastNWidgets(1));
  });

  testWidgets('MoviePosterCard uses FocusableControl on mobile for focus border',
      (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.mobile,
        child: MoviePosterCard(movie: _testMovie(), onTap: () {}),
      ),
    );
    expect(find.byType(FocusableControl), findsOneWidget);
  });

  testWidgets('ForjaShellChip is focusable on tv profile', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: ForjaShellChip(label: 'Action', onTap: () {}),
      ),
    );
    expect(find.byType(FocusableControl), findsOneWidget);
  });

  testWidgets('shellTvRegisterRow registers catalog row for tv tab', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: Builder(
          builder: (context) {
            shellTvRegisterRow(
              tabId: 'home',
              rowId: 'smoke-row',
              sortOrder: 0,
              itemCount: 3,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(
      ShellTvFocusCoordinator.moveVerticalInTab(
        tabId: 'home',
        rowId: 'smoke-row',
        currentIndex: 2,
        down: true,
      ),
      isTrue,
    );
  });
}
