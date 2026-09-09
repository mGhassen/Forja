/// Marks [aggregateLiveFeed] while the hub JS `ctx.host.liveFeed.load` bridge
/// is in flight (flutter_js holds the outer fork).
///
/// Nested `runLiveFeed` must not wait on / fork flutter_js (deadlock / JSC
/// crash — issue 237). Sibling scrapes ([metaFeedCatalogProvider]) must still
/// queue on the flutter_js mutex — do not treat any busy flutter_js as nest.
int _hubLiveFeedBridgeDepth = 0;

bool get isUnderHubLiveFeedBridge => _hubLiveFeedBridgeDepth > 0;

Future<T> withHubLiveFeedBridge<T>(Future<T> Function() body) async {
  _hubLiveFeedBridgeDepth++;
  try {
    return await body();
  } finally {
    _hubLiveFeedBridgeDepth--;
  }
}
