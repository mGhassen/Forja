import 'dart:convert';

import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/pastesh_decryptor.dart';
import 'package:forja_api/api/kisskh_subtitle_decryptor.dart';
import 'package:forja_api/api/stremio_service.dart';
import 'package:forja_api/api/torrent_filter.dart';
import 'package:forja_core/utils/episode_matcher.dart';
import 'package:forja_core/utils/hls_master_parser.dart';
import 'package:forja_rust/src/dart_fallback.dart';
import 'package:forja_scrapers/scrapers/scraper_parse.dart';
import 'package:forja_webstreamr/webstreamr/utils/unpacker.dart';

/// Wires Dart fallback parsers into `*Backend` hooks when Rust delegates are absent.
void installDartFallbackDelegates() {
  EpisodeMatcherBackend.matches ??= EpisodeMatcherDart.matches;
  HlsParserBackend.parseMaster ??= HlsDartParse.parseMaster;

  TorrentFilterBackend.normalizeTitle ??= TorrentFilterDart.normalizeTitle;
  TorrentFilterBackend.parseSceneInfo ??= TorrentFilterDart.parseSceneInfo;

  StremioServiceBackend.splitAddonUrl ??= StremioDartParse.splitAddonUrl;
  StremioServiceBackend.buildResourceUrl ??= StremioDartParse.buildResourceUrl;
  StremioServiceBackend.normalizeManifestUrl ??=
      StremioDartParse.normalizeManifestUrl;
  StremioServiceBackend.parseManifestJson ??= (body) {
    final manifest = StremioDartParse.parseManifestJson(body);
    return jsonEncode(manifest);
  };
  StremioServiceBackend.parseStreamsJson ??= StremioDartParse.parseStreamsJson;
  StremioServiceBackend.parseSubtitlesJson ??=
      StremioDartParse.parseSubtitlesJson;
  StremioServiceBackend.parseCatalogJson ??= StremioDartParse.parseCatalogJson;
  StremioServiceBackend.parseMetaJson ??= (body) {
    return StremioDartParse.parseMetaJson(body);
  };

  ScraperParseBackend.parseKnaben ??= (html) =>
      ScrapersDartParse.parseKnaben(html);
  ScraperParseBackend.parseTpb ??= (html, source) =>
      ScrapersDartParse.parseTpb(html, source);
  ScraperParseBackend.parseUindex ??= (html) =>
      ScrapersDartParse.parseUindex(html);
  ScraperParseBackend.dedupTorrents ??= ScrapersDartParse.dedupTorrents;

  PasteShDecryptorBackend.decryptRaw ??= PasteShDecryptDart.decryptRaw;

  IptvClientBackend.decodeXtreamText ??= IptvDartParse.decodeXtreamText;
  IptvClientBackend.parseCategoriesJson ??=
      (text) => jsonEncode(IptvDartParse.parseCategoriesRows(text));
  IptvClientBackend.parseStreamsJson ??= (text, section) =>
      jsonEncode(IptvDartParse.parseStreamsRows(text, section));
  IptvClientBackend.parseSeriesEpisodesJson ??=
      (text) => jsonEncode(IptvDartParse.parseSeriesEpisodesRows(text));

  JsUnpackBackend.unpack ??= (source) {
    final out = JsUnpackerDart.unpack(source);
    return out.isEmpty ? null : out;
  };

  KissKhDecryptBackend.decryptBody ??= (body, sourceUrl) =>
      KissKhDecryptDart.decryptBody(body, sourceUrl: sourceUrl);
}
