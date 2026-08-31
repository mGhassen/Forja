/// Pack-declared catalog hub capability keys (`EnginePlugin.capabilities`).
///
/// Host chrome reads [EnginePlugin.hasCapability] only — never pluginId / tabId.
class CatalogHubCapabilities {
  CatalogHubCapabilities._();

  /// Pack implements `action: 'search'`.
  static const String search = 'search';

  /// Pack implements `action: 'filters'` and honors `params.filter` on browse/search.
  static const String filters = 'filters';

  /// Pack parses RFC-058 structured query tokens in `search` (person/year/score/…).
  /// Host mounts the tune / filter lens when this is present (kit [CatalogSearchScreen]).
  static const String structuredSearch = 'structured_search';

  /// Use the shared host Search overlay (Cmd+F / RFC-058 + addons) instead of
  /// pack-only kit [CatalogSearchScreen]. Top-bar Search and Cmd+F must match.
  static const String hostSearch = 'host_search';
}
