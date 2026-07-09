/// Forja anime streaming servers — player-facing ids with internal pipe keys.
class AnimeStreamServer {
  final String id;
  final String pipeKey;

  const AnimeStreamServer({required this.id, required this.pipeKey});
}

class AnimeStreamServers {
  static const neko = AnimeStreamServer(id: 'neko', pipeKey: 'zoro');
  static const momo = AnimeStreamServer(id: 'momo', pipeKey: 'kiwi');
  static const kumo = AnimeStreamServer(id: 'kumo', pipeKey: 'bee');
  static const yuki = AnimeStreamServer(id: 'yuki', pipeKey: 'hop');
  static const kiri = AnimeStreamServer(id: 'kiri', pipeKey: 'bonk');
  static const kiko = AnimeStreamServer(id: 'kiko', pipeKey: 'ally');
  static const peko = AnimeStreamServer(id: 'peko', pipeKey: 'moo');
  static const mugi = AnimeStreamServer(id: 'mugi', pipeKey: 'animedunya');
  static const riku = AnimeStreamServer(id: 'riku', pipeKey: 'arc');
  static const tora = AnimeStreamServer(id: 'tora', pipeKey: 'jet');

  /// Race order — neko first, tora last.
  static const List<AnimeStreamServer> all = [
    neko,
    momo,
    kumo,
    yuki,
    kiri,
    kiko,
    peko,
    mugi,
    riku,
    tora,
  ];

  static final Map<String, AnimeStreamServer> _byId = {
    for (final s in all) s.id: s,
  };

  static final Map<String, AnimeStreamServer> _byPipe = {
    for (final s in all) s.pipeKey: s,
  };

  static final RegExp _urlRe = RegExp(
    r'^forja://anilist/(\d+)/(\d+)/(sub|dub)/([a-z]+)$',
  );

  static bool isForjaServer(String server) => _byId.containsKey(server);

  static AnimeStreamServer? byId(String id) => _byId[id.toLowerCase()];

  static AnimeStreamServer? byPipeKey(String key) => _byPipe[key.toLowerCase()];

  static int priorityIndex(String serverId) {
    final i = all.indexWhere((s) => s.id == serverId);
    return i >= 0 ? i : 99;
  }

  static String streamUrl({
    required int anilistId,
    required int episode,
    required String category,
    required AnimeStreamServer server,
  }) =>
      'forja://anilist/$anilistId/$episode/$category/${server.id}';

  static ({int anilistId, int episode, String category, AnimeStreamServer server})?
      parseUrl(String url) {
    final m = _urlRe.firstMatch(url);
    if (m == null) return null;
    final srv = byId(m.group(4)!);
    if (srv == null) return null;
    return (
      anilistId: int.parse(m.group(1)!),
      episode: int.parse(m.group(2)!),
      category: m.group(3)!,
      server: srv,
    );
  }
}
