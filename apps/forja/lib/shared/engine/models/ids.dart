/// Sources kind + chip ids. Kind id is `engine`, not `forja`
/// (`forja` is the legacy Torrents All-chip alias).
abstract final class EngineIds {
  static const kind = 'engine';
  static const allChip = 'all_engine';
  static const prefix = 'engine:';
  static const tabLabel = 'Forja';

  static bool isKind(String id) => id == kind;

  static bool isAllChip(String id) => id == allChip;

  static bool isPluginChip(String id) => id.startsWith(prefix);

  static String pluginChip(String pluginId) => '$prefix$pluginId';

  static String? pluginIdFromChip(String id) {
    if (!isPluginChip(id)) return null;
    final rest = id.substring(prefix.length);
    return rest.isEmpty ? null : rest;
  }
}
