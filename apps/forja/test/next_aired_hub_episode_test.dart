import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/player/screens/utils.dart';

void main() {
  const aired1 = PlayerKitEpisode(number: 1, title: 'E1');
  const aired2 = PlayerKitEpisode(number: 2, title: 'E2');
  const unaired3 =
      PlayerKitEpisode(number: 3, title: 'E3', notShippedYet: true);
  final list = [aired1, aired2, unaired3];

  test('next aired episode is offered', () {
    expect(nextAiredHubEpisode(list, 0), same(aired2));
    expect(adjacentHubEpisodeFlags(list, 1).hasNext, isTrue);
  });

  test('unaired next episode hides Next Episode', () {
    expect(nextAiredHubEpisode(list, 1), isNull);
    expect(adjacentHubEpisodeFlags(list, 2).hasNext, isFalse);
    expect(adjacentHubEpisodeFlags(list, 2).hasPrev, isTrue);
  });

  test('last episode has no next', () {
    expect(nextAiredHubEpisode(list, 2), isNull);
    expect(adjacentHubEpisodeFlags(list, 3).hasNext, isFalse);
  });
}
