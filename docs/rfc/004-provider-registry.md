# RFC-004: ProviderRegistry

## Registry

`StreamProviderDef` with `ProviderKind`: template | extractor | api

MVP providers: videasy, vidsrc, vidnest, vidlink, vixsrc, vidzee, vidrock, service111477

## Resolver

`StreamResolver.resolve()` tries enabled providers in user order.
`switchProvider()` re-extracts at current playback position.

Settings: `ProviderSettingsRepo` — order, enabled, lastUsed.
