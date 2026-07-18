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
  int _iptvCredits = 0;

  /// Reddit / Find Portals scrape in the IPTV tab.
  bool get isIptvScrapeEnabled => _iptvScrape;

  /// Credits for dealing portals from the catalog pool (RFC-040).
  int get iptvCredits => _iptvCredits;

  /// Apply lean cloud JSON (`{}` or `{ "iptvScrape": true }`).
  void applyRemote(Map<String, dynamic>? raw, {int? iptvCredits}) {
    final nextScrape = raw != null && raw['iptvScrape'] == true;
    final nextCredits = (iptvCredits ?? _iptvCredits).clamp(0, 1 << 30);
    if (nextScrape == _iptvScrape && nextCredits == _iptvCredits) return;
    _iptvScrape = nextScrape;
    _iptvCredits = nextCredits;
    revision.value++;
  }

  /// Update credits only (after a deal).
  void setIptvCredits(int value) {
    final next = value.clamp(0, 1 << 30);
    if (next == _iptvCredits) return;
    _iptvCredits = next;
    revision.value++;
  }

  /// Reset to all-off (sign-out / guest).
  void clear() {
    if (!_iptvScrape && _iptvCredits == 0) return;
    _iptvScrape = false;
    _iptvCredits = 0;
    revision.value++;
  }
}
