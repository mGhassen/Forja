import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:rust/rust.dart' show RichMediaDetails;

/// Host adapters for details enrich (RFC-106 G11 — no TmdbApi in kit UI).
///
/// Pack-only backdrops always work via [hubHeroBackdropUrls]. TMDB fetch
/// registers here from `shared/host/details`.
typedef KitDetailsTmdbBackdropLoader = Future<List<String>> Function(
  MetaItem meta, {
  required List<String> packUrls,
});

typedef KitDetailsTmdbRichLoader = Future<RichMediaDetails?> Function(
  MetaItem meta,
);

typedef KitDetailsTmdbLogoUrl = String? Function(RichMediaDetails? rich);

abstract final class KitDetailsHostHooks {
  KitDetailsHostHooks._();

  static KitDetailsTmdbBackdropLoader? loadTmdbBackdropUrls;
  static KitDetailsTmdbRichLoader? loadTmdbRich;
  static KitDetailsTmdbLogoUrl? tmdbLogoUrl;

  static void clear() {
    loadTmdbBackdropUrls = null;
    loadTmdbRich = null;
    tmdbLogoUrl = null;
  }
}
