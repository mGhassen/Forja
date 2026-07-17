import 'package:flutter/foundation.dart';

/// Account-level remote feature flags (`accounts.features`).
///
/// Empty / missing cloud payload means all features off. Guests and signed-out
/// sessions stay disabled until a signed-in pull applies enabled keys.
class AccountFeatures {
  AccountFeatures._();
  static final AccountFeatures instance = AccountFeatures._();

  /// Bumps when any flag changes (IPTV UI listens).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _iptvScrape = false;

  /// Reddit / Find Portals scrape in the IPTV tab.
  bool get isIptvScrapeEnabled => _iptvScrape;

  /// Apply lean cloud JSON (`{}` or `{ "iptvScrape": true }`).
  void applyRemote(Map<String, dynamic>? raw) {
    final next = raw != null && raw['iptvScrape'] == true;
    if (next == _iptvScrape) return;
    _iptvScrape = next;
    revision.value++;
  }

  /// Reset to all-off (sign-out / guest).
  void clear() {
    if (!_iptvScrape) return;
    _iptvScrape = false;
    revision.value++;
  }
}
