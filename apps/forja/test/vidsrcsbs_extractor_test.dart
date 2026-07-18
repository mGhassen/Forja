import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/providers/vidsrcsbs/vidsrcsbs_extractor.dart';

void main() {
  group('VidsrcsbsExtractor.parseServersHtml', () {
    test('orders PRO Multi before Star from live CFG shape', () {
      const html = '''
<script>
var CFG = {
    type:    'tv',
    tmdbId:  279323,
    servers: [{"id":"server_a","name":"Star","movie_url":"https://1embed.cc/embed/movie/{tmdb_id}","tv_url":"https://1embed.cc/embed/tv/{tmdb_id}/{season}/{episode}"},{"id":"server_b","name":"PRO Multi","movie_url":"https://web.nxsha.app/embed/movie/{tmdb_id}","tv_url":"https://web.nxsha.app/embed/tv/{tmdb_id}/{season}/{episode}"},{"id":"server_c","name":"Cinesrc","movie_url":"https://cinesrc.st/embed/movie/{tmdb_id}","tv_url":"https://cinesrc.st/embed/tv/{tmdb_id}?s={season}&e={episode}"},{"id":"server_d","name":"Vlux","movie_url":"https://vidlux.xyz/embed/movie/{tmdb_id}","tv_url":"https://vidlux.xyz/embed/tv/{tmdb_id}/{season}/{episode}"}]};
</script>
''';
      final servers = VidsrcsbsExtractor.parseServersHtml(html);
      expect(servers.map((s) => s.name).toList(), [
        'PRO Multi',
        'Cinesrc',
        'Vlux',
        'Star',
      ]);
      expect(
        servers.first.resolveUrl(
          isMovie: false,
          tmdbId: '279323',
          season: 1,
          episode: 1,
        ),
        'https://web.nxsha.app/embed/tv/279323/1/1',
      );
    });
  });
}
