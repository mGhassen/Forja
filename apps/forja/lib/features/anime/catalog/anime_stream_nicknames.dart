/// Player-facing nicknames for every anime stream source.
class AnimeStreamNicknames {
  AnimeStreamNicknames._();

  // Anikoto embed hosts
  static const String megaplay = 'Kaiju';
  static const String vidwish = 'Ronin';

  // Adult fallbacks
  static const String watchhentai = 'Oni';
  static const String hentaini = 'Sakura';

  static const Map<String, String> _miruroPipe = {
    'zoro': 'Chibi',
    'kiwi': 'Nori',
    'bee': 'Tofu',
    'hop': 'Tako',
    'bonk': 'Miso',
    'ally': 'Ramen',
    'moo': 'Pocky',
    'animedunya': 'Dango',
    'arc': 'Udon',
    'jet': 'Onigiri',
    'bun': 'Matcha',
    'kuz': 'Kitsune',
    'telli': 'Tanuki',
  };

  static const Map<String, String> _allAnime = {
    'Default': 'Shiro',
    'S-mp4': 'Akira',
    'Yt-mp4': 'Raijin',
    'Luf-Mp4': 'Fujin',
    'Uv-mp4': 'Tengu',
  };

  static String forMiruroPipe(String pipeKey) =>
      _miruroPipe[pipeKey.toLowerCase()] ?? pipeKey;

  static String forAllAnime(String provider) => _allAnime[provider] ?? provider;

  static String forServer(String server, {String? key}) {
    switch (server) {
      case 'megaplay':
        return megaplay;
      case 'vidwish':
        return vidwish;
      case 'miruro':
        return forMiruroPipe(key ?? '');
      case 'allanime':
        return forAllAnime(key ?? '');
      case 'animerealms':
        return key ?? 'AnimeRealms';
      case 'watchhentai':
        return watchhentai;
      case 'hentaini':
        return hentaini;
      default:
        return key ?? server;
    }
  }
}
