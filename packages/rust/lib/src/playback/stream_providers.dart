import 'provider_registry.dart';

/// Built-in stream provider catalog for player/settings UI.
/// URLs come from [ProviderRegistry] → Rust `stream` via [Engine].
class StreamProviders {
  static Map<String, dynamic> get providers => ProviderRegistry.catalog;
}
