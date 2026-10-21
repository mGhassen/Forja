/// Shared failover gate for the player screens (Exo, mobile, desktop).
///
/// Consulted after the player has walked every source it was given. A
/// prevalidated list (the green Play race already probed the rows) skips
/// re-probing, not recovery: when the host left a reload hook, the player may
/// still ask it for more streams once its own rows are exhausted.
bool canAutoHopAfterSourcesExhausted({
  required bool pinned,
  required bool streamsPrevalidated,
  required bool hasMovie,
  required bool hasProviders,
  required bool hostOwnsReload,
}) {
  if (pinned) return false;
  if (!hasMovie) return false;
  if (streamsPrevalidated && !hostOwnsReload) return false;
  return hasProviders || hostOwnsReload;
}
