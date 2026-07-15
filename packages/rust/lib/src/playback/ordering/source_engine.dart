import '../providers/registry/provider_profiles.dart';
import '../domain/source_domain.dart';
import 'source_order_engine.dart';

/// Domain-scoped orchestration — which providers compete for this content.
///
/// Preferred mode:
/// - [auto] → filter to domain-supported ids, sort by settings baseline
///   with bounded domain-score adjustment (±[maxProviderDisplacement])
/// - any other id → strict: only that provider (must support the domain)
abstract final class SourceEngine {
  static const String auto = 'auto';

  /// Ordered provider ids for [domain].
  static List<String> orderProviderIds({
    required SourceDomain domain,
    required Iterable<String> candidateIds,
    String preferred = auto,
    List<String> settingsOrder = const [],
  }) => orderProviders(
    domain: domain,
    candidateIds: candidateIds,
    preferred: preferred,
    settingsOrder: settingsOrder,
  ).orderedIds;

  /// Full ordering breakdown for UI previews and tests.
  static ProviderOrderResult orderProviders({
    required SourceDomain domain,
    required Iterable<String> candidateIds,
    String preferred = auto,
    List<String> settingsOrder = const [],
  }) => SourceOrderEngine.orderProviders(
    domain: domain,
    candidateIds: candidateIds,
    preferred: preferred,
    settingsOrder: settingsOrder,
  );

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

  /// Configured domain score for a provider (0 = unsupported).
  static int domainScore(String providerId, SourceDomain domain) =>
      ProviderProfiles.resolve(providerId).scoreFor(domain);
}
