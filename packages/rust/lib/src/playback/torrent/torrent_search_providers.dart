/// Builtin torrent search provider ids (must match `crates/scrapers` PROVIDER_IDS).
class TorrentSearchProviders {
  static const knaben = 'knaben';
  static const pirateBay = 'pirate_bay';
  static const uindex = 'uindex';
  static const torrentsCsv = 'torrents_csv';
  static const nyaa = 'nyaa';
  static const yts = 'yts';
  static const solidTorrents = 'solid_torrents';
  static const therarbg = 'therarbg';
  static const torrentio = 'torrentio';

  static const all = <String>[
    knaben,
    pirateBay,
    uindex,
    torrentsCsv,
    nyaa,
    yts,
    solidTorrents,
    therarbg,
    torrentio,
  ];

  static const labels = <String, String>{
    knaben: 'Knaben',
    pirateBay: 'The Pirate Bay',
    uindex: 'UIndex',
    torrentsCsv: 'Torrents CSV',
    nyaa: 'Nyaa',
    yts: 'YTS',
    solidTorrents: 'SolidTorrents',
    therarbg: 'TheRARBG',
    torrentio: 'Torrentio',
  };

  static String label(String id) => labels[id] ?? id;
}
