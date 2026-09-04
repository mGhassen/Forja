/// Host-owned images plugins may reference — never Flutter `assets/…` paths.
///
/// Plugin manifests use `forja://asset/{id}` (e.g. `forja://asset/nav/home`).
/// The host maps [id] → a bundled Flutter asset. Plugin authors only need the
/// Forja URI / id list; the real path stays inside the app.
library;

import 'package:flutter/material.dart';

abstract final class ForjaHostAssets {
  static const scheme = 'forja';
  static const host = 'asset';
  static const uriPrefix = 'forja://asset/';

  static const flutterNavHome = 'assets/images/nav/home.png';
  static const flutterNavAnime = 'assets/images/nav/anime.png';
  static const flutterNavAsianDrama = 'assets/images/nav/asian-drama.png';
  static const flutterNavArabic = 'assets/images/nav/arabic.png';
  static const flutterNavSearch = 'assets/images/nav/search.png';
  static const flutterNavLiveMatches = 'assets/images/nav/live-matches.png';
  static const flutterNavIptv = 'assets/images/nav/iptv.png';

  static const uriNavHome = '${uriPrefix}nav/home';
  static const uriNavAnime = '${uriPrefix}nav/anime';
  static const uriNavAsianDrama = '${uriPrefix}nav/asian-drama';
  static const uriNavArabic = '${uriPrefix}nav/arabic';
  static const uriNavCartoon = '${uriPrefix}nav/cartoon';
  static const uriNavBrstej = '${uriPrefix}nav/brstej';
  static const uriNavKids = '${uriPrefix}nav/kids';
  static const uriNavSearch = '${uriPrefix}nav/search';
  static const uriNavLiveMatches = '${uriPrefix}nav/live-matches';
  static const uriNavIptv = '${uriPrefix}nav/iptv';
  static const uriNavMyList = '${uriPrefix}nav/my-list';

  /// Material glyph when pack/host icon is missing or fails to load.
  static const IconData defaultNavIcon = Icons.grid_view_rounded;

  /// Public id → Flutter asset path. Extend here when shipping new host icons.
  static const Map<String, String> catalog = {
    'nav/home': flutterNavHome,
    'nav/anime': flutterNavAnime,
    'nav/asian-drama': flutterNavAsianDrama,
    'nav/arabic': flutterNavArabic,
    'nav/search': flutterNavSearch,
    'nav/live-matches': flutterNavLiveMatches,
    'nav/iptv': flutterNavIptv,
  };

  static Iterable<String> get ids => catalog.keys;

  static String uriFor(String id) => '$uriPrefix$id';

  /// Parses `forja://asset/nav/home` → `nav/home`. Null if not a Forja asset ref.
  static String? parseId(String? ref) {
    final raw = ref?.trim();
    if (raw == null || raw.isEmpty) return null;
    final u = Uri.tryParse(raw);
    if (u == null || u.scheme != scheme || u.host != host) return null;
    final id = u.path.replaceFirst(RegExp(r'^/+'), '');
    return id.isEmpty ? null : id;
  }

  /// Resolves a plugin `nav.icon` (or any Forja asset URI) to a Flutter path.
  /// Returns null for unknown ids, raw `assets/…`, or Material names.
  static String? resolveFlutterPath(String? ref) {
    final id = parseId(ref);
    if (id == null) return null;
    return catalog[id];
  }

  static bool isKnown(String? ref) {
    if (resolveFlutterPath(ref) != null) return true;
    return materialIconFor(ref) != null;
  }

  /// Material fallback when a pack icon is a known host asset id.
  static IconData? materialIconFor(String? ref) {
    final id = parseId(ref);
    if (id == null) return null;
    return switch (id) {
      'nav/home' => Icons.home_outlined,
      'nav/anime' => Icons.animation_outlined,
      'nav/asian-drama' => Icons.theater_comedy_outlined,
      'nav/arabic' => Icons.movie_filter_outlined,
      'nav/cartoon' => Icons.toys_outlined,
      'nav/brstej' => Icons.live_tv_outlined,
      'nav/kids' => Icons.child_care_outlined,
      'nav/search' => Icons.search_outlined,
      'nav/live-matches' => Icons.sports_soccer_outlined,
      'nav/iptv' => Icons.live_tv_outlined,
      'nav/my-list' => Icons.bookmark_outline,
      _ => null,
    };
  }
}
