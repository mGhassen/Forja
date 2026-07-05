import 'provider_registry.dart';

/// Built-in stream provider catalog for player/settings UI.
/// URLs come from [ProviderRegistry] → Rust `stream-core` via [ForjaEngine].
class StreamProviders {
  static Map<String, dynamic> get providers => ProviderRegistry.catalog;
}
