import 'provider_profiles.dart';
import 'source_domain.dart';

/// Domain-scoped orchestration — which providers compete for this content.
///
/// Preferred mode:
/// - [auto] → filter to domain-supported ids, sort by profile priority
///   then optional settings order as tiebreak
/// - any other id → strict: only that provider (must support the domain)
abstract final class SourceEngine {
  static const String auto = 'auto';

  /// Ordered provider ids for [domain].
  static List<String> orderProviderIds({
    required SourceDomain domain,
    required Iterable<String> candidateIds,
    String preferred = auto,
    List<String> settingsOrder = const [],
  }) {
    final candidates = candidateIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != auto)
        .toSet()
        .toList();
    if (candidates.isEmpty) return const [];

    final pin = preferred.trim();
    if (pin.isNotEmpty && pin != auto) {
      if (!candidates.contains(pin)) return const [];
      final profile = ProviderProfiles.resolve(pin);
      if (!profile.supports(domain)) return const [];
      return [pin];
    }

    final supported = <String>[];
    for (final id in candidates) {
      final profile = ProviderProfiles.of(id);
      // Known profile that doesn't support this domain → drop.
      // Unknown ids (Nuvio / unlisted anime mirrors) stay — caller scoped the set.
      if (profile != null && !profile.supports(domain)) continue;
      supported.add(id);
    }
    if (supported.isEmpty) return const [];

    final orderIndex = <String, int>{
      for (var i = 0; i < settingsOrder.length; i++) settingsOrder[i]: i,
    };

    supported.sort((a, b) {
      final sa = ProviderProfiles.resolve(a).scoreFor(domain);
      final sb = ProviderProfiles.resolve(b).scoreFor(domain);
      if (sa != sb) return sb.compareTo(sa);
      final ia = orderIndex[a] ?? 10000;
      final ib = orderIndex[b] ?? 10000;
      if (ia != ib) return ia.compareTo(ib);
      return a.compareTo(b);
    });
    return supported;
  }

  /// Reorder a provider map for [domain] (preserves values).
  static Map<String, T> orderProvidersMap<T>({
    required SourceDomain domain,
    required Map<String, T> providers,
    String preferred = auto,
    List<String> settingsOrder = const [],
  }) {
    final ordered = orderProviderIds(
      domain: domain,
      candidateIds: providers.keys,
      preferred: preferred,
      settingsOrder: settingsOrder,
    );
    return <String, T>{
      for (final id in ordered)
        if (providers.containsKey(id)) id: providers[id] as T,
    };
  }

  static bool isAuto(String? preferred) {
    final p = (preferred ?? auto).trim();
    return p.isEmpty || p == auto;
  }

  /// Providers after [currentId] in domain Auto order (for failover).
  static List<String> nextProviderIds({
    required SourceDomain domain,
    required Iterable<String> candidateIds,
    String? currentId,
    List<String> settingsOrder = const [],
  }) {
    final ordered = orderProviderIds(
      domain: domain,
      candidateIds: candidateIds,
      preferred: auto,
      settingsOrder: settingsOrder,
    );
    if (ordered.isEmpty) return const [];
    final cur = (currentId ?? '').trim();
    if (cur.isEmpty) return ordered;
    final idx = ordered.indexOf(cur);
    if (idx < 0) return ordered;
    if (idx + 1 >= ordered.length) return const [];
    return ordered.sublist(idx + 1);
  }
}
