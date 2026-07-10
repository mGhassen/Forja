import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/design/src/forja_shell_chip.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
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
            expect(shellMovieCardWidth(context), 220);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('HomeMovieCard uses FocusableControl on tv profile', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: HomeMovieCard(movie: _testMovie(), onTap: () {}),
      ),
    );
    expect(find.byType(FocusableControl), findsOneWidget);
  });

  testWidgets('HomeMovieCard uses InkWell on mobile profile', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.mobile,
        child: HomeMovieCard(movie: _testMovie(), onTap: () {}),
      ),
    );
    expect(find.byType(FocusableControl), findsNothing);
    expect(find.byType(InkWell), findsWidgets);
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
}
