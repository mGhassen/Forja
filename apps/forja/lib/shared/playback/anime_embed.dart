import 'package:forja/shared/playback/provider_runtime_config.dart';

/// Legacy anime panel provider descriptor (engine playback UI).
class AnimeEmbed {
  final String label;
  final String server;
  final String category;
  final String url;

  const AnimeEmbed({
    required this.label,
    required this.server,
    required this.category,
    required this.url,
  });

  String get displayName => '$label · ${category.toUpperCase()}';

  String get panelKey => '$sourceKey:$category';

  String get sourceKey {
    switch (server) {
      case 'anikoto':
        return 'anikoto';
      case 'miruro':
        final uri = Uri.parse(url.replaceFirst('miruro://', 'https://'));
        final prov = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        return 'miruro:$prov';
      case 'allanime':
        final uri = Uri.parse(url.replaceFirst('allanime://', 'https://'));
        final segs = uri.pathSegments;
        if (segs.length >= 4) return 'allanime:${segs[3]}';
        return 'allanime:default';
      case 'animerealms':
        final uri = Uri.parse(url.replaceFirst('animerealms://', 'https://'));
        final prov = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        return 'animerealms:$prov';
      case 'vidnest':
        final uri = Uri.parse(url.replaceFirst('vidnest://', 'https://'));
        final prov = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        return 'vidnest:$prov';
      default:
        return server;
    }
  }

  String get refererOrigin {
    switch (server) {
      case 'miruro':
        final remote = ProviderRuntimeConfig.instance.miruroOrigins;
        final o = remote.isNotEmpty ? remote.first : 'https://www.miruro.tv';
        return o.endsWith('/') ? o.substring(0, o.length - 1) : o;
      case 'allanime':
        return 'https://allmanga.to';
      case 'vidnest':
        return 'https://vidnest.fun';
      case 'vidlink':
        return 'https://vidlink.pro';
      case 'animerealms':
        return 'https://www.animerealms.org';
      case 'watchhentai':
        return 'https://watchhentai.net';
      case 'hentaini':
        return 'https://hentaini.com';
      default:
        return 'https://${ProviderRuntimeConfig.instance.megaplay.host}';
    }
  }
}

class AnikotoSeries {
  const AnikotoSeries({
    required this.id,
    this.slug = '',
    this.aniId,
    this.episodes = const [],
  });

  final int id;
  final String slug;
  final int? aniId;
  final List<AnikotoEpisode> episodes;
}

class AnikotoEpisode {
  const AnikotoEpisode({
    required this.id,
    required this.number,
    required this.title,
    required this.embedId,
  });

  final int id;
  final int number;
  final String title;
  final String embedId;
}
