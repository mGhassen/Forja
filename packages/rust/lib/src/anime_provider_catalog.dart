// Static provider id lists for settings UI (extractors live in engine plugins).

const allAnimeKnownProviders = [
  'Default',
  'Yt-mp4',
  'S-mp4',
  'Luf-Mp4',
];

const miruroKnownProviders = [
  'zoro',
  'kiwi',
  'bee',
  'hop',
  'bonk',
  'ally',
  'moo',
  'animedunya',
  'arc',
  'jet',
  'bun',
  'kuz',
  'telli',
];

const miruroUpstreamSources = <String, String>{
  'kiwi': 'AnimePahe',
  'ally': 'AllManga',
  'bonk': 'AnimeDao',
  'bee': 'AniKoto',
  'moo': 'AnimeGG',
  'hop': 'Miruro',
  'arc': 'Miruro internal',
  'zoro': 'HiAnime',
  'jet': 'Miruro internal',
  'animedunya': 'AnimeDunya',
  'bun': 'Miruro',
  'kuz': 'Miruro',
  'telli': 'Miruro',
};

const vidnestKnownProviders = ['hianime', 'animepahe'];

const vidnestUpstreamLabels = <String, String>{
  'hianime': 'VidNest HiAnime',
  'animepahe': 'VidNest AnimePahe',
};

String miruroUpstreamLabel(String pipeKey) =>
    miruroUpstreamSources[pipeKey.toLowerCase()] ?? pipeKey;
