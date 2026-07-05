/// Dart engine fallbacks when the native library is unavailable (debug / pre-build).
/// Parity tests import these modules to compare Rust FFI output.
library;

export 'dart_fallback/episode_matcher_dart.dart';
export 'dart_fallback/hls_dart_parse.dart';
export 'dart_fallback/iptv_dart_parse.dart';
export 'dart_fallback/js_unpacker_dart.dart';
export 'dart_fallback/kisskh_decrypt_dart.dart';
export 'dart_fallback/m3u_dart_parser.dart';
export 'dart_fallback/pastesh_decrypt_dart.dart';
export 'dart_fallback/scrapers_dart_parse.dart';
export 'dart_fallback/stremio_dart_parse.dart';
export 'dart_fallback/torrent_filter_dart.dart';
