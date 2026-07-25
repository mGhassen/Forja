import 'package:flutter/foundation.dart';

/// Account-level remote feature flags (`accounts.features` + `accounts.is_admin`).
///
/// Empty / missing cloud payload means all features off. Guests and signed-out
/// sessions stay disabled until a signed-in pull applies enabled keys.
class AccountFeatures {
  AccountFeatures._();
  static final AccountFeatures instance = AccountFeatures._();

  /// Bumps when any flag changes (IPTV UI listens).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _iptvScrape = false;
  bool _dealPortal = false;
  int _iptvCredits = 0;
  bool _isAdmin = false;

  /// Reddit / Find Portals scrape in the IPTV tab.
  bool get isIptvScrapeEnabled => _iptvScrape;

  /// Deal lottery packs from the catalog pool (requires credits separately).
  bool get isDealPortalEnabled => _dealPortal;

  /// Credits for dealing portals from the catalog pool (RFC-040).
  int get iptvCredits => _iptvCredits;

  /// `accounts.is_admin` - experimental / ops toggles in Settings.
  bool get isAdmin => _isAdmin;

  /// Apply lean cloud JSON (`{}` or `{ "iptvScrape": true, "dealPortal": true }`).
  void applyRemote(
    Map<String, dynamic>? raw, {
    int? iptvCredits,
    bool? isAdmin,
  }) {
    final nextScrape = raw != null && raw['iptvScrape'] == true;
    final nextDeal = raw != null && raw['dealPortal'] == true;
    final nextCredits = (iptvCredits ?? _iptvCredits).clamp(0, 1 << 30);
    final nextAdmin = isAdmin ?? _isAdmin;
    if (nextScrape == _iptvScrape &&
        nextDeal == _dealPortal &&
        nextCredits == _iptvCredits &&
        nextAdmin == _isAdmin) {
      return;
    }
    _iptvScrape = nextScrape;
    _dealPortal = nextDeal;
    _iptvCredits = nextCredits;
    _isAdmin = nextAdmin;
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
    if (!_iptvScrape && !_dealPortal && _iptvCredits == 0 && !_isAdmin) {
      return;
    }
    _iptvScrape = false;
    _dealPortal = false;
    _iptvCredits = 0;
    _isAdmin = false;
    revision.value++;
  }
}
