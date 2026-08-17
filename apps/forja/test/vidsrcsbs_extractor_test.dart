import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/providers/vidsrcsbs/profile.dart';
import 'package:forja/shared/extractors/providers/vidsrcsbs/vidsrcsbs_extractor.dart';
import 'package:forja/shared/playback/host_provider_adapter.dart';

void main() {
  group('VidsrcsbsExtractor.parseServersHtml', () {
    test('keeps CFG.servers order (no preferred reorder)', () {
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
        'Star',
        'PRO Multi',
        'Cinesrc',
        'Vlux',
      ]);
      expect(
        servers.first.resolveUrl(
          isMovie: false,
          tmdbId: '279323',
          season: 1,
          episode: 1,
        ),
        'https://1embed.cc/embed/tv/279323/1/1',
      );
    });
  });

  test('VidSrc.sbs nested sniff rotates chips and waits for all top mirrors', () {
    expect(vidsrcsbsNestedExtractProfile.rotateServerChips, isTrue);
    expect(
      HostProviderAdapter.vidsrcsbsWebviewSniffConcurrencyForTest,
      lessThanOrEqualTo(2),
    );
  });

  test('videasy nested URLs use STREAMCRYPTO HTTP, not WebView sniff', () {
    expect(
      HostProviderAdapter.vidsrcsbsUsesStreamCrypto(
        'https://player.videasy.net/movie/496243',
      ),
      isTrue,
    );
    expect(
      HostProviderAdapter.vidsrcsbsUsesStreamCrypto(
        'https://player.videasy.to/movie/496243',
      ),
      isTrue,
    );
    expect(
      HostProviderAdapter.vidsrcsbsUsesStreamCrypto(
        'https://cinesrc.st/embed/movie/496243',
      ),
      isFalse,
    );
    expect(
      HostProviderAdapter.vidsrcsbsUsesStreamCrypto(
        'https://web.nxsha.app/embed/movie/496243?server=AwsPly',
      ),
      isFalse,
    );
  });
}
