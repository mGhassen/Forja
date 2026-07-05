import 'package:forja_storage/forja_storage.dart';

import 'extracted_media.dart';
import 'provider_registry.dart';
import 'videasy_extractor.dart';
import 'vidsrc_extractor.dart';
import 'stream_extractor.dart';

class StreamResolver {
  StreamResolver({
    ProviderSettingsRepo? settings,
    void Function(String)? onLog,
  })  : _settings = settings ?? ProviderSettingsRepo(),
        _onLog = onLog ?? _noop;

  final ProviderSettingsRepo _settings;
  final void Function(String) _onLog;
  final StreamExtractor _extractor = StreamExtractor();
  final VideasyExtractor _videasy = VideasyExtractor(onLog: _noop);
  final VidsrcExtractor _vidsrc = VidsrcExtractor();

  static void _noop(String _) {}

  Future<List<StreamProviderDef>> getActiveProviders() async {
    final order = await _settings.getOrder();
    final enabled = await _settings.getEnabled();
    return ProviderRegistry.ordered(order, enabled);
  }

  Future<ResolvedStream?> resolve({
    required ResolveContext ctx,
    String? preferredProviderId,
  }) async {
    final providers = await getActiveProviders();
    final ordered = preferredProviderId == null
        ? providers
        : [
            ...providers.where((p) => p.id == preferredProviderId),
            ...providers.where((p) => p.id != preferredProviderId),
          ];

    for (final p in ordered) {
      final r = await _resolveOne(p, ctx);
      if (r != null) {
        await _settings.setLastUsed(p.id);
        return r;
      }
    }
    return null;
  }

  Future<ResolvedStream?> switchProvider({
    required String providerId,
    required ResolveContext ctx,
  }) =>
      resolve(ctx: ctx, preferredProviderId: providerId);

  Future<ResolvedStream?> _resolveOne(
    StreamProviderDef p,
    ResolveContext ctx,
  ) async {
    _onLog('Trying ${p.displayName}…');
    try {
      switch (p.id) {
        case 'videasy':
          final m = await _videasy.extract(
            tmdbId: ctx.tmdbId,
            isMovie: ctx.isMovie,
            season: ctx.season,
            episode: ctx.episode,
          );
          if (m?.url != null) {
            return ResolvedStream(
              providerId: p.id,
              url: m!.url,
              headers: m.headers,
              sources: m.sources,
              externalSubtitles: m.externalSubtitles,
            );
          }
          return null;
        case 'vidsrc':
          final m = await _vidsrc.extract(
            tmdbId: ctx.tmdbId,
            isMovie: ctx.isMovie,
            season: ctx.season,
            episode: ctx.episode,
          );
          if (m?.url != null) {
            return ResolvedStream(
              providerId: p.id,
              url: m!.url,
              headers: m.headers,
              sources: m.sources,
            );
          }
          return null;
        default:
          if (p.kind == ProviderKind.template) {
            final embed = ctx.isMovie
                ? p.movieUrl!(ctx.tmdbId)
                : p.tvUrl!(ctx.tmdbId, ctx.season ?? 1, ctx.episode ?? 1);
            final m = await _extractor.extract(embed);
            if (m?.url != null) {
              return ResolvedStream(
                providerId: p.id,
                url: m!.url,
                headers: m.headers,
                sources: m.sources,
              );
            }
          }
          return null;
      }
    } catch (e) {
      _onLog('${p.displayName} failed: $e');
      return null;
    }
  }
}
