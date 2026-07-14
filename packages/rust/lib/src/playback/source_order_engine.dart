import 'dart:convert';

import 'package:rust/src/engine.dart';
import 'package:rust/src/playback/source_domain.dart';

/// Per-provider ordering breakdown from the Rust Source Engine.
class ProviderOrderRow {
  const ProviderOrderRow({
    required this.id,
    required this.settingsRank,
    required this.domainScore,
    required this.effectiveRank,
    required this.maxDisplacement,
    required this.supported,
    this.reliabilityScore = 0,
  });

  final String id;
  final int settingsRank;
  final int domainScore;
  /// Sum of per-title reliability totals for this provider (across titles).
  final int reliabilityScore;
  final int effectiveRank;
  final int maxDisplacement;
  final bool supported;

  factory ProviderOrderRow.fromJson(Map<String, dynamic> json) => ProviderOrderRow(
        id: json['id']?.toString() ?? '',
        settingsRank: (json['settings_rank'] as num?)?.toInt() ?? 0,
        domainScore: (json['domain_score'] as num?)?.toInt() ?? 0,
        reliabilityScore: (json['reliability_score'] as num?)?.toInt() ?? 0,
        effectiveRank: (json['effective_rank'] as num?)?.toInt() ?? 0,
        maxDisplacement: (json['max_displacement'] as num?)?.toInt() ?? 2,
        supported: json['supported'] == true,
      );
}

class ProviderOrderResult {
  const ProviderOrderResult({
    required this.orderedIds,
    required this.rows,
  });

  final List<String> orderedIds;
  final List<ProviderOrderRow> rows;

  Map<String, ProviderOrderRow> get rowById => {
        for (final row in rows) row.id: row,
      };
}

/// Maximum positions a provider may move from its settings baseline rank.
const int maxProviderDisplacement = 2;

/// Rust-backed provider ordering — settings baseline with bounded domain adjustment.
abstract final class SourceOrderEngine {
  static ProviderOrderResult orderProviders({
    required SourceDomain domain,
    required Iterable<String> candidateIds,
    String preferred = 'auto',
    List<String> settingsOrder = const [],
  }) {
    final payload = jsonEncode({
      'domain': _domainId(domain),
      'candidate_ids': candidateIds.toList(),
      'settings_order': settingsOrder,
      'preferred': preferred,
    });
    final raw = RustLib.instance.playbackOrderProvidersJson(payload);
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['error'] != null) {
      return const ProviderOrderResult(orderedIds: [], rows: []);
    }
    final map = Map<String, dynamic>.from(decoded as Map);
    final ordered = (map['ordered_ids'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const <String>[];
    final rows = (map['rows'] as List?)
            ?.map((e) => ProviderOrderRow.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(growable: false) ??
        const <ProviderOrderRow>[];
    return ProviderOrderResult(orderedIds: ordered, rows: rows);
  }

  static int domainScore(String providerId, SourceDomain domain) {
    final result = orderProviders(
      domain: domain,
      candidateIds: [providerId],
      settingsOrder: [providerId],
    );
    return result.rows.isEmpty ? 0 : result.rows.first.domainScore;
  }

  static String _domainId(SourceDomain domain) => switch (domain) {
        SourceDomain.movies => 'movies',
        SourceDomain.series => 'series',
        SourceDomain.anime => 'anime',
        SourceDomain.asianDrama => 'asian_drama',
        SourceDomain.iptv => 'iptv',
        SourceDomain.torrent => 'torrent',
      };
}
