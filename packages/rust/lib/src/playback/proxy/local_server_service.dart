import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'dart:convert';

/// Thin wrapper around the Rust local proxy (`crates/proxy`).
class LocalServerService {
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  int _port = 0;

  int get port => _port;
  String get baseUrl => _port > 0 ? 'http://127.0.0.1:$_port' : '';

  Future<void> start() async {
    if (_port > 0) return;
    if (!Engine.isReady) return;

    final rustPort = RustLib.instance.proxyStart(0);
    if (rustPort > 0) {
      _port = rustPort;
      debugPrint('[LocalServer] Rust proxy on 127.0.0.1:$rustPort');
    }
  }

  String getTokyProxyUrl(String url, String id, String token, String src) {
    return '$baseUrl/toky-proxy?url=${Uri.encodeComponent(url)}'
        '&id=${Uri.encodeComponent(id)}'
        '&token=${Uri.encodeComponent(token)}'
        '&src=${Uri.encodeComponent(src)}';
  }

  String getComicProxyUrl(String url) {
    return '$baseUrl/comic-proxy?url=${Uri.encodeComponent(url)}';
  }

  String getJellyfinProxyUrl(String targetUrl, String authHeaderValue) {
    return '$baseUrl/jellyfin-stream'
        '?url=${Uri.encodeComponent(targetUrl)}'
        '&auth=${Uri.encodeComponent(authHeaderValue)}';
  }

  String getHlsProxyUrl(
    String targetUrl,
    Map<String, String> headers, {
    String? stripMode,
  }) {
    final base =
        '$baseUrl/hls-proxy'
        '?url=${Uri.encodeComponent(targetUrl)}'
        '&headers=${Uri.encodeComponent(json.encode(headers))}';
    return stripMode == null ? base : '$base&strip=$stripMode';
  }

  /// Path-style proxy for external players (`/ext/{id}/{entry}`).
  ///
  /// Holds Cookie/Referer in the session so relative DASH SegmentTemplate and
  /// HLS playlists resolve under the proxy. Falls back to [getHlsProxyUrl] if
  /// the engine cannot create a session.
  String getExtProxyUrl(String targetUrl, Map<String, String> headers) {
    if (_port <= 0 || !Engine.isReady) {
      return getHlsProxyUrl(targetUrl, headers);
    }
    final play = RustLib.instance.proxyCreateExtSession(
      targetUrl,
      json.encode(headers),
    );
    if (play.isEmpty) {
      debugPrint('[LocalServer] ext session failed — falling back to hls-proxy');
      return getHlsProxyUrl(targetUrl, headers);
    }
    return play;
  }

  Future<void> stop() async {
    if (_port > 0 && Engine.isReady) {
      RustLib.instance.proxyStop();
      _port = 0;
    }
  }
}
