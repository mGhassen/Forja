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

  seasonAwareTests();
}

void seasonAwareTests() {
  const s1e1 = PlayerKitEpisode(number: 1, title: 'S1E1', season: 1);
  const s1e2 = PlayerKitEpisode(number: 2, title: 'S1E2', season: 1);
  const s2e1 = PlayerKitEpisode(number: 1, title: 'S2E1', season: 2);
  const s2e2 = PlayerKitEpisode(number: 2, title: 'S2E2', season: 2);
  const s3e1 =
      PlayerKitEpisode(number: 1, title: 'S3E1', season: 3, notShippedYet: true);
  final seasons = [s1e1, s1e2, s2e1, s2e2, s3e1];

  test('season picks the row of that season, not the first number match', () {
    expect(hubEpisodeIndex(seasons, 2, season: 2), 3);
    expect(hubEpisodeIndex(seasons, 2, season: 1), 1);
    expect(hubEpisodeIndex(seasons, 2), 1);
  });

  test('next after the last episode of a season is the next season opener', () {
    final idx = hubEpisodeIndex(seasons, 2, season: 1)!;
    expect(nextAiredHubEpisode(seasons, idx), same(s2e1));
    expect(adjacentHubEpisodeFlags(seasons, 2, season: 1).hasNext, isTrue);
  });

  test('unaired next season opener hides Next Episode', () {
    expect(adjacentHubEpisodeFlags(seasons, 2, season: 2).hasNext, isFalse);
    expect(adjacentHubEpisodeFlags(seasons, 1, season: 2).hasPrev, isTrue);
  });

  test('unknown season falls back to the first number match', () {
    expect(hubEpisodeIndex(seasons, 2, season: 9), 1);
  });

  test('flat lists ignore the season hint', () {
    const flat = [
      PlayerKitEpisode(number: 1, title: 'E1'),
      PlayerKitEpisode(number: 2, title: 'E2'),
    ];
    expect(hubEpisodeIndex(flat, 2, season: 4), 1);
  });
}
