/// Dart fallback URL templates when the Rust engine is off.
abstract final class ProviderFallbackUrls {
  static String vidlinkMovie(String id) => 'https://vidlink.pro/movie/$id';
  static String vidlinkTv(String id, int s, int e) =>
      'https://vidlink.pro/tv/$id/$s/$e';

  static String vixsrcMovie(String id) => 'https://vixsrc.to/movie/$id/';
  static String vixsrcTv(String id, int s, int e) =>
      'https://vixsrc.to/tv/$id/$s/$e/';

  static String vidnestMovie(String id) => 'https://vidnest.fun/movie/$id';
  static String vidnestTv(String id, int s, int e) =>
      'https://vidnest.fun/tv/$id/$s/$e';

  static String vidzeeMovie(String id) => 'https://vidzee.wtf/movie/$id';
  static String vidzeeTv(String id, int s, int e) =>
      'https://vidzee.wtf/tv/$id/$s/$e';

  static String vidrockMovie(String id) => 'https://vidrock.net/movie/$id';
  static String vidrockTv(String id, int s, int e) =>
      'https://vidrock.net/tv/$id/$s/$e';
}
