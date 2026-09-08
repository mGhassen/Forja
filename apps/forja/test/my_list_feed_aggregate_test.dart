import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/lists/my_list_feed_aggregate.dart';

void main() {
  group('MyListFeedQuery.fromHostParams', () {
    test('defaults status and empty hidden keys', () {
      final q = MyListFeedQuery.fromHostParams(null);
      expect(q.status, 'plantowatch');
      expect(q.hiddenKeys, isEmpty);
    });

    test('reads status and hiddenKeys list', () {
      final q = MyListFeedQuery.fromHostParams({
        'status': 'watching',
        'hiddenKeys': ['tmdb_movie_1', '', 'anilist_2'],
      });
      expect(q.status, 'watching');
      expect(q.hiddenKeys, {'tmdb_movie_1', 'anilist_2'});
    });

    test('reads listStatus alias and comma hidden_keys', () {
      final q = MyListFeedQuery.fromHostParams({
        'listStatus': 'completed',
        'hidden_keys': 'tmdb_tv_9, kisskh_3',
      });
      expect(q.status, 'completed');
      expect(q.hiddenKeys, {'tmdb_tv_9', 'kisskh_3'});
    });
  });
}
