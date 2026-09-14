/// Opaque portal engine — vault inventory, network helpers, M3U, share crypto.
///
/// Product catalog caches / channel search / sports gates live in packs.
/// Channel-guide UI lives under `shared/player/live/channel_guide/` (host
/// adapters) + `forja_foundation/widgets/guide/` (paint).
library;

export 'channel_search/match_fixture_keys.dart';
export 'm3u/m3u_models.dart';
export 'm3u/m3u_parser.dart';
export 'm3u/m3u_store.dart';
export 'models.dart';
export 'network/iptv_network.dart';
export 'network/pastesh_decryptor.dart';
export 'share/iptv_portal_csv.dart';
export 'share/iptv_portal_share.dart';
export 'store/iptv_vault_inventory.dart';
export 'store/storage.dart';
