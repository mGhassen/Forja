/// Maps Miruro pipe provider keys to AnimeRealms API provider names.
String toAnimeRealmsProvider(String provider) {
  switch (provider.toLowerCase()) {
    case 'zoro':
      return 'hianime';
    case 'kiwi':
      return 'animepahe';
    case 'ally':
      return 'allmanga';
    case 'bonk':
      return 'gogoanime';
    case 'bee':
      return 'animekai';
    case 'moo':
      return 'zencloud';
    default:
      return provider.toLowerCase();
  }
}
