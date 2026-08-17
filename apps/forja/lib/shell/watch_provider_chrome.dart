import 'package:flutter/material.dart';

/// Curated Home watch-provider chrome — local SVG + contrasting tile color.
class WatchProviderChrome {
  const WatchProviderChrome({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.tileColor,
    this.inset = 0.14,
    this.forceWhiteLogo = false,
  });

  /// TMDB watch provider id (chrome key). Discover ORs same-brand ids
  /// (Max includes HBO / HBO Max).
  final int id;
  final String name;
  final String assetPath;

  /// Tile behind the SVG — must contrast the logo fills.
  final Color tileColor;

  /// Fractional inset so wordmarks fill the tile without clipping.
  final double inset;

  /// Recolor SVG to white (when the asset is a dark/brand-colored wordmark
  /// on a brand-colored tile).
  final bool forceWhiteLogo;
}

/// Home filter panel order — local HD SVGs under [assets/watch_providers].
const List<WatchProviderChrome> kHomeWatchProviderChrome = [
  WatchProviderChrome(
    id: 8,
    name: 'Netflix',
    assetPath: 'assets/watch_providers/netflix.svg',
    tileColor: Color(0xFF000000),
    inset: 0.16,
  ),
  // Logo fill is dark blue (#01147c) — needs a light tile.
  WatchProviderChrome(
    id: 337,
    name: 'Disney+',
    assetPath: 'assets/watch_providers/disneyplus.svg',
    tileColor: Color(0xFFFFFFFF),
    inset: 0.12,
  ),
  WatchProviderChrome(
    id: 9,
    name: 'Prime Video',
    assetPath: 'assets/watch_providers/primevideo.svg',
    tileColor: Color(0xFF000000),
    inset: 0.14,
  ),
  WatchProviderChrome(
    id: 350,
    name: 'Apple TV+',
    assetPath: 'assets/watch_providers/appletv.svg',
    tileColor: Color(0xFF000000),
    inset: 0.2,
  ),
  // Asset is blue wordmark — paint white on Max blue.
  WatchProviderChrome(
    id: 1899,
    name: 'Max',
    assetPath: 'assets/watch_providers/max.svg',
    tileColor: Color(0xFF002BE7),
    inset: 0.18,
    forceWhiteLogo: true,
  ),
  // Hulu wordmark is green — black tile, never green-on-green.
  WatchProviderChrome(
    id: 15,
    name: 'Hulu',
    assetPath: 'assets/watch_providers/hulu.svg',
    tileColor: Color(0xFF000000),
    inset: 0.2,
  ),
  WatchProviderChrome(
    id: 2303,
    name: 'Paramount+',
    assetPath: 'assets/watch_providers/paramountplus.svg',
    tileColor: Color(0xFF0064FF),
    inset: 0.14,
    forceWhiteLogo: true,
  ),
  // Peacock mark is dark + multicolor — light tile.
  WatchProviderChrome(
    id: 386,
    name: 'Peacock',
    assetPath: 'assets/watch_providers/peacock.svg',
    tileColor: Color(0xFFFFFFFF),
    inset: 0.14,
  ),
  WatchProviderChrome(
    id: 283,
    name: 'Crunchyroll',
    assetPath: 'assets/watch_providers/crunchyroll.svg',
    tileColor: Color(0xFF000000),
    inset: 0.16,
  ),
  // Tubi yellow wordmark — dark purple, keep native yellow (no forceWhite).
  WatchProviderChrome(
    id: 73,
    name: 'Tubi',
    assetPath: 'assets/watch_providers/tubi.svg',
    tileColor: Color(0xFF4B0082),
    inset: 0.18,
  ),
];

WatchProviderChrome? watchProviderChromeById(int id) {
  for (final p in kHomeWatchProviderChrome) {
    if (p.id == id) return p;
  }
  return null;
}
