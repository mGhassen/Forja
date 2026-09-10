/// Published pack row from admin catalog (`plugin_packs`).
///
/// Built from Supabase only — no baked host inventory. Admin owns
/// `official`, `recommended`, `manifest_url`, and publish state.
class OfficialForjaHqPack {
  const OfficialForjaHqPack({
    required this.id,
    required this.name,
    required this.manifestUrl,
    this.description,
    this.tags = const [],
    this.kind,
    this.recommended = false,
    this.official = false,
  });

  final String id;
  final String name;
  final String manifestUrl;

  /// Short human blurb (same text as pack `manifest.json` / catalog).
  final String? description;

  /// Topic tags from the public catalog (`anime`, `live`, …).
  final List<String> tags;

  /// Catalog kind (`hubs`, `providers`, `live`, …).
  final String? kind;

  /// Soft CTA — Recommended badge on Official packs picker / web catalog.
  final bool recommended;

  /// Admin Official flag — ForjaHQ / first-party set for install prompts.
  final bool official;
}

const kCommunityPacksUrl = 'https://www.forjahq.xyz/plugins';
