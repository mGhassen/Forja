library;

export 'catalog_extract_context.dart';
export 'categories.dart';
export 'ids.dart';
export 'lean_apply_result.dart';
export 'live_goat_unlock.dart';
export 'live_sport_capabilities.dart';
export 'models.dart';
export 'official_forjahq_packs.dart';
export 'pack_device_state.dart';
export 'plugin_contract.dart';
export 'plugin_install_coordinator.dart';
export 'plugin_install_prompt.dart';
export 'plugin_install_prompt_service.dart';
export 'plugin_install_validator.dart';
export 'plugin_registry.dart';
export 'plugin_script_disk_store.dart';
export 'remote_pack_intent_store.dart';
export 'runtime.dart';
export 'service.dart';

/// Catalog hub wire types — `runCatalog` returns these envelopes. Cache /
/// runtime / shell live behind `shared/catalog/catalog.dart` so the engine
/// barrel stays widget-free.
export '../catalog/protocol.dart';
