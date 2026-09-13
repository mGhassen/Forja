/// Marks hub JS while a nested `ctx.host.plugin.*` call is in flight
/// (flutter_js holds the outer fork).
///
/// Nested live catalog `runLiveFeed` must not wait on / fork flutter_js
/// (deadlock / JSC crash — issue 237). Sibling scrapes must still queue on
/// the flutter_js mutex — do not treat any busy flutter_js as nest.
int _hubHostBridgeDepth = 0;

bool get isUnderHubHostBridge => _hubHostBridgeDepth > 0;

/// @Deprecated('Use isUnderHubHostBridge')
bool get isUnderHubLiveFeedBridge => isUnderHubHostBridge;

Future<T> withHubHostBridge<T>(Future<T> Function() body) async {
  _hubHostBridgeDepth++;
  try {
    return await body();
  } finally {
    _hubHostBridgeDepth--;
  }
}

/// @Deprecated('Use withHubHostBridge')
Future<T> withHubLiveFeedBridge<T>(Future<T> Function() body) =>
    withHubHostBridge(body);
