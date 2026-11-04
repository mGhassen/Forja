import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/brand/forja_profile_avatar.dart';

void main() {
  testWidgets('renders all fifty-six web profile avatars', (tester) async {
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
      'invader',
      'ghost',
      'knight',
      'wizard',
      'toad',
      'heartbit',
      'boombox',
      'chip',
      'wolf',
      'bear',
      'penguin',
      'frog',
      'lion',
      'bee',
      'elf',
      'orc',
      'fairy',
      'golem',
      'phoenix',
      'mermaid',
      'cyborg',
      'hacker',
      'drone',
      'matrix',
      'laser',
      'android',
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

    expect(find.byType(SvgPicture), findsNWidgets(56));
    expect(tester.takeException(), isNull);
  });
}
