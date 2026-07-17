import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';

void main() {
  testWidgets('renders all thirty web profile avatars', (tester) async {
    const keys = [
      'forge',
      'flame',
      'mint',
      'captain',
      'rebel',
      'ninja',
      'royal',
      'racer',
      'night',
      'panda',
      'fox',
      'owl',
      'shark',
      'dragon',
      'bunny',
      'yeti',
      'orbit',
      'comet',
      'nova',
      'alien',
      'rover',
      'lunar',
      'solar',
      'void',
      'pixel',
      'arcade',
      'cassette',
      'glitch',
      'neon',
      'synth',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Wrap(
            children: [
              for (final key in keys)
                ForjaProfileAvatar(avatarKey: key, name: key, size: 64),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(30));
    expect(tester.takeException(), isNull);
  });
}
