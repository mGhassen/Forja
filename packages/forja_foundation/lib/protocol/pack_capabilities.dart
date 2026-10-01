/// Pack-declared catalog hub capability keys (`EnginePlugin.capabilities`).
///
/// Host chrome reads [EnginePlugin.hasCapability] only — never pluginId / tabId.
class PackCapabilities {
  PackCapabilities._();

  /// Pack implements `action: 'search'`.
  static const String search = 'search';

  /// Pack implements `action: 'search_helpers'` — idle / contextual title
  /// suggestions for the search left column (never mirrors result cards).
  static const String searchHelpers = 'search_helpers';

  /// Pack implements `action: 'filters'` and honors `params.filter` on browse/search.
  static const String filters = 'filters';

  /// Pack parses RFC-058 structured query tokens in `search` (person/year/score/…).
  /// Host mounts the tune / filter lens when this is present (kit [KitSearchScreen]).
  static const String structuredSearch = 'structured_search';
}
