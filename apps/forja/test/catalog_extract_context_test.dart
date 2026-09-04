import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/catalog_extract_context.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:rust/rust.dart';

Movie _movie({required int id, String mediaType = 'tv'}) => Movie(
      id: id,
      title: 't',
      posterPath: '',
      backdropPath: '',
      voteAverage: 0,
      releaseDate: '',
      mediaType: mediaType,
    );

void main() {
  test('episodeVideoId overwrites show-level extract ctx videoId', () {
    final open = CatalogOpen(
      surface: 'arabic',
      id: 'serShow',
      extract: const CatalogOpenExtract(
        resolveType: 'arabic',
        panelCategory: 'arabic',
        ctx: {'videoId': 'serShow', 'source': 'larozaa'},
      ),
    );
    final ctx = engineExtractContext(
      catalogOpen: open,
      movie: _movie(id: 1),
      episode: 3,
      episodeVideoId: 'larozaa:999',
    );
    expect(ctx.ctx['videoId'], 'larozaa:999');
    expect(ctx.ctx['episodeVideoId'], 'larozaa:999');

    final cfg = injectExtractCtxIntoConfig(
      EnginePlugin.fromJson({
        'id': 'test-provider-a',
        'name': 'Test',
        'entry': 'x.js',
        'kind': 'http',
        'types': ['arabic'],
        'ctxConfigMap': {'videoId': 'videoId'},
      }),
      ctx.ctx,
      const {},
    );
    expect(cfg['videoId'], 'larozaa:999');
  });

  test('show-level videoId kept when episodeVideoId absent', () {
    final open = CatalogOpen(
      surface: 'arabic',
      id: 'movieVid',
      extract: const CatalogOpenExtract(
        resolveType: 'arabic',
        panelCategory: 'arabic',
        ctx: {'videoId': 'movieVid', 'source': 'larozaa'},
      ),
    );
    final ctx = engineExtractContext(
      catalogOpen: open,
      movie: _movie(id: 2, mediaType: 'movie'),
    );
    expect(ctx.ctx['videoId'], 'movieVid');
    expect(ctx.ctx.containsKey('episodeVideoId'), isFalse);
  });
}
