import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';

/// Icon + accent for [kit.categoryBar] mood circles (Live Sports kinds).
({IconData icon, Color accent}) catalogKitCategoryCircleMeta(String raw) {
  final key = raw
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[\s_/]+'), '-');
  if (key.isEmpty || key == 'all') {
    return (
      icon: Icons.grid_view_rounded,
      accent: ForjaShellColors.sectionAccent,
    );
  }
  if (key.contains('american-football') ||
      key == 'nfl' ||
      key.contains('ncaaf')) {
    return (
      icon: Icons.sports_football_rounded,
      accent: const Color(0xFF22C55E),
    );
  }
  if (key.contains('basketball') ||
      key.contains('nba') ||
      key.contains('ncaab') ||
      key.contains('wnba')) {
    return (
      icon: Icons.sports_basketball_rounded,
      accent: const Color(0xFFF97316),
    );
  }
  // Soccer before generic "football" — kind ids use `football` for soccer.
  if (key.contains('soccer') ||
      key == 'football' ||
      key.contains('fifa') ||
      key.contains('premier-league') ||
      key.contains('la-liga') ||
      key.contains('serie-a') ||
      key.contains('bundesliga')) {
    return (
      icon: Icons.sports_soccer_rounded,
      accent: const Color(0xFF10B981),
    );
  }
  if (key.contains('baseball') || key.contains('mlb')) {
    return (
      icon: Icons.sports_baseball_rounded,
      accent: const Color(0xFFEF4444),
    );
  }
  if (key.contains('hockey') || key.contains('nhl')) {
    return (
      icon: Icons.sports_hockey_rounded,
      accent: const Color(0xFF38BDF8),
    );
  }
  if (key.contains('tennis') || key.contains('tenis') || key.contains('atp')) {
    return (
      icon: Icons.sports_tennis_rounded,
      accent: const Color(0xFFA3E635),
    );
  }
  if (key.contains('cricket') ||
      key.contains('krykiet') ||
      key.contains('ipl')) {
    return (
      icon: Icons.sports_cricket_rounded,
      accent: const Color(0xFF84CC16),
    );
  }
  if (key.contains('rugby') ||
      key.contains('nrl') ||
      key.contains('afl') ||
      key.contains('australian-football')) {
    return (
      icon: Icons.sports_rugby_rounded,
      accent: const Color(0xFF16A34A),
    );
  }
  // Remaining *-football slugs (after american / australian).
  if (key.contains('football')) {
    return (
      icon: Icons.sports_soccer_rounded,
      accent: const Color(0xFF10B981),
    );
  }
  if (key.contains('golf')) {
    return (
      icon: Icons.sports_golf_rounded,
      accent: const Color(0xFF65A30D),
    );
  }
  if (key.contains('volleyball') || key.contains('volley')) {
    return (
      icon: Icons.sports_volleyball_rounded,
      accent: const Color(0xFF06B6D4),
    );
  }
  if (key.contains('handball')) {
    return (
      icon: Icons.sports_handball_rounded,
      accent: const Color(0xFF0EA5E9),
    );
  }
  if (key.contains('wrestling') ||
      key.contains('wwe') ||
      key.contains('ufc') ||
      key.contains('mma') ||
      key.contains('boxing') ||
      key.contains('fight') ||
      key.contains('combat') ||
      key.contains('martial')) {
    return (icon: Icons.sports_mma_rounded, accent: const Color(0xFFF43F5E));
  }
  if (key.contains('motor') ||
      key.contains('racing') ||
      key.contains('f1') ||
      key.contains('nascar') ||
      key.contains('formula')) {
    return (
      icon: Icons.sports_motorsports_rounded,
      accent: const Color(0xFFEAB308),
    );
  }
  if (key.contains('dart')) {
    return (icon: Icons.gps_fixed_rounded, accent: const Color(0xFFEC4899));
  }
  if (key.contains('snooker') ||
      key.contains('billiard') ||
      key == 'pool' ||
      key.contains('8-ball')) {
    return (icon: Icons.circle_rounded, accent: const Color(0xFF14B8A6));
  }
  if (key.contains('swim') || key.contains('aquatic')) {
    return (icon: Icons.pool_rounded, accent: const Color(0xFF3B82F6));
  }
  if (key.contains('ski') || key.contains('snow') || key.contains('winter')) {
    return (
      icon: Icons.downhill_skiing_rounded,
      accent: const Color(0xFF94A3B8),
    );
  }
  if (key.contains('esport') ||
      key.contains('e-sport') ||
      key.contains('gaming')) {
    return (
      icon: Icons.sports_esports_rounded,
      accent: const Color(0xFFA855F7),
    );
  }
  if (key.contains('24-7') ||
      key.contains('24/7') ||
      key.contains('live-tv') ||
      key.contains('livetv') ||
      key.contains('tv-show') ||
      key.contains('big-brother') ||
      key.contains('reality') ||
      key.contains('stream')) {
    return (icon: Icons.live_tv_rounded, accent: const Color(0xFF8B5CF6));
  }
  if (key.contains('misc') || key.contains('other') || key.contains('general')) {
    return (icon: Icons.sports_rounded, accent: const Color(0xFF64748B));
  }
  return (icon: Icons.sports_rounded, accent: ForjaShellColors.sectionAccent);
}

/// Display label for a kind id (`american-football` → `American Football`).
String catalogKitCategoryLabel(String id, {String? label}) {
  final trimmed = (label ?? '').trim();
  if (trimmed.isNotEmpty && trimmed.toLowerCase() != id.toLowerCase()) {
    return trimmed;
  }
  final key = id.trim();
  if (key.isEmpty || key == 'all') return 'All';
  if (key == '24-7' || key == '24/7') return '24/7';
  return key
      .split(RegExp(r'[-_]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
