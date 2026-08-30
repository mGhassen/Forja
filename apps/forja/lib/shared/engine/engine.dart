library;

export 'anime_ids.dart';
export 'catalog_extract_context.dart';
export 'categories.dart';
export 'ids.dart';
export 'live_goat_unlock.dart';
export 'models.dart';
export 'plugin_registry.dart';
export 'runtime.dart';
export 'service.dart';

/// Catalog hub wire types — `runCatalog` returns these envelopes. Cache /
/// runtime / shell live behind `shared/catalog/catalog.dart` so the engine
/// barrel stays widget-free.
export '../catalog/protocol.dart';
