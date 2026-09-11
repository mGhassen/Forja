import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Icon + accent for [kit.categoryBar] mood circles.
///
/// [icon] is a pack token (`soccer`, `basketball`, …). Host does not infer
/// sports from kind ids.
({IconData icon, Color accent}) kitMoodCircleMeta({
  String id = '',
  String? icon,
}) {
  final token = (icon ?? '').trim().toLowerCase();
  if (token.isNotEmpty) return kitMoodIconToken(token);
  final key = id.toLowerCase().trim();
  if (key.isEmpty || key == 'all') {
    return (
      icon: Icons.grid_view_rounded,
      accent: ForjaShellColors.sectionAccent,
    );
  }
  return (
    icon: Icons.sports_rounded,
    accent: ForjaShellColors.sectionAccent,
  );
}

/// Pack-declared mood icon tokens. Not sport-name matching.
({IconData icon, Color accent}) kitMoodIconToken(String token) {
  return switch (token.trim().toLowerCase()) {
    'grid' || 'all' => (
        icon: Icons.grid_view_rounded,
        accent: ForjaShellColors.sectionAccent,
      ),
    'soccer' => (
        icon: Icons.sports_soccer_rounded,
        accent: const Color(0xFF10B981),
      ),
    'football' => (
        icon: Icons.sports_football_rounded,
        accent: const Color(0xFF22C55E),
      ),
    'basketball' => (
        icon: Icons.sports_basketball_rounded,
        accent: const Color(0xFFF97316),
      ),
    'baseball' => (
        icon: Icons.sports_baseball_rounded,
        accent: const Color(0xFFEF4444),
      ),
    'hockey' => (
        icon: Icons.sports_hockey_rounded,
        accent: const Color(0xFF38BDF8),
      ),
    'tennis' => (
        icon: Icons.sports_tennis_rounded,
        accent: const Color(0xFFA3E635),
      ),
    'cricket' => (
        icon: Icons.sports_cricket_rounded,
        accent: const Color(0xFF84CC16),
      ),
    'rugby' => (
        icon: Icons.sports_rugby_rounded,
        accent: const Color(0xFF16A34A),
      ),
    'golf' => (
        icon: Icons.sports_golf_rounded,
        accent: const Color(0xFF65A30D),
      ),
    'volleyball' => (
        icon: Icons.sports_volleyball_rounded,
        accent: const Color(0xFF06B6D4),
      ),
    'handball' => (
        icon: Icons.sports_handball_rounded,
        accent: const Color(0xFF0EA5E9),
      ),
    'mma' => (icon: Icons.sports_mma_rounded, accent: const Color(0xFFF43F5E)),
    'motorsport' => (
        icon: Icons.sports_motorsports_rounded,
        accent: const Color(0xFFEAB308),
      ),
    'darts' => (icon: Icons.gps_fixed_rounded, accent: const Color(0xFFEC4899)),
    'billiards' => (
        icon: Icons.circle_rounded,
        accent: const Color(0xFF14B8A6),
      ),
    'swim' => (icon: Icons.pool_rounded, accent: const Color(0xFF3B82F6)),
    'ski' => (
        icon: Icons.downhill_skiing_rounded,
        accent: const Color(0xFF94A3B8),
      ),
    'esports' => (
        icon: Icons.sports_esports_rounded,
        accent: const Color(0xFFA855F7),
      ),
    'tv' => (icon: Icons.live_tv_rounded, accent: const Color(0xFF8B5CF6)),
    _ => (
        icon: Icons.sports_rounded,
        accent: ForjaShellColors.sectionAccent,
      ),
  };
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

Map<String, String> kitCategoryBarKindIcons(Map<String, dynamic> spec) {
  final raw = spec['kindIcons'];
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      e.key.toString().trim().toLowerCase():
          e.value.toString().trim().toLowerCase(),
  };
}
