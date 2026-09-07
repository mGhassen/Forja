import 'package:flutter/foundation.dart';

/// Account-level remote feature flags (`accounts.features` + `accounts.is_admin`
/// + `accounts.iptv_credits`).
///
/// Empty / missing cloud payload means all boolean features off. Guests and
/// signed-out sessions stay disabled until a signed-in pull applies enabled
/// keys. Portal cap defaults to [defaultMaxIptvPortals] when
/// `features.maxIptvPortals` is omitted (admins unlimited).
class AccountFeatures {
  AccountFeatures._();
  static final AccountFeatures instance = AccountFeatures._();

  /// Default max Xtream portals per profile when the lean key is absent.
  static const int defaultMaxIptvPortals = 5;

  /// Hard ceiling matching the admin RPC clamp.
  static const int absoluteMaxIptvPortals = 500;

  /// Bumps when any flag changes (IPTV UI listens).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _iptvScrape = false;
  bool _dealPortal = false;
  int _iptvCredits = 0;
  bool _isAdmin = false;
  int _maxIptvPortals = defaultMaxIptvPortals;
  int? _memberNumber;

  /// Reddit / Find Portals scrape in the IPTV tab.
  bool get isIptvScrapeEnabled => _iptvScrape;

  /// Deal lottery packs from the catalog pool (requires credits separately).
  bool get isDealPortalEnabled => _dealPortal;

  /// Credits for dealing portals from the catalog pool (RFC-040).
  int get iptvCredits => _iptvCredits;

  /// Opaque internal member id (`accounts.member_number`) for ops / PostHog.
  /// Null when signed out or column not yet available.
  int? get memberNumber => _memberNumber;

  /// `accounts.is_admin` — experimental / ops toggles in Settings (Webstreaming
  /// play source, Debrid, Lists, About Privacy/Developer,
  /// Simple resolve, …). Unlimited IPTV portals. Forja Sports Settings is not
  /// admin-gated.
  bool get isAdmin => _isAdmin;

  /// Configured max portals per profile (`features.maxIptvPortals`, default 5).
  /// Ignored when [hasUnlimitedIptvPortals].
  int get maxIptvPortals => _maxIptvPortals;

  /// Admin accounts skip the portal inventory cap.
  bool get hasUnlimitedIptvPortals => _isAdmin;

  /// Whether [currentCount] portals can accept one more assignment.
  bool canAddIptvPortal(int currentCount) {
    if (hasUnlimitedIptvPortals) return true;
    return currentCount < _maxIptvPortals;
  }

  /// How many more portals may be added (very large when unlimited).
  int iptvPortalSlotsRemaining(int currentCount) {
    if (hasUnlimitedIptvPortals) return absoluteMaxIptvPortals;
    final left = _maxIptvPortals - currentCount;
    return left < 0 ? 0 : left;
  }

  /// User-facing limit label (e.g. for tooltips).
  String iptvPortalLimitLabel() {
    if (hasUnlimitedIptvPortals) return 'Unlimited';
    return '$_maxIptvPortals';
  }

  /// Message when Add / scrape / deal / import hits the cap.
  String iptvPortalLimitReachedMessage() {
    if (hasUnlimitedIptvPortals) return 'Portal limit reached.';
    return 'Maximum of $_maxIptvPortals portals per profile';
  }

  static int _parseMaxIptvPortals(Map<String, dynamic>? raw) {
    if (raw == null) return defaultMaxIptvPortals;
    final v = raw['maxIptvPortals'];
    final n = switch (v) {
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s),
      _ => null,
    };
    if (n == null) return defaultMaxIptvPortals;
    return n.clamp(1, absoluteMaxIptvPortals);
  }

  /// Apply lean cloud JSON
  /// (`{}` or `{ "iptvScrape": true, "dealPortal": true, "maxIptvPortals": 20 }`).
  void applyRemote(
    Map<String, dynamic>? raw, {
    int? iptvCredits,
    bool? isAdmin,
    int? memberNumber,
  }) {
    final nextScrape = raw != null && raw['iptvScrape'] == true;
    final nextDeal = raw != null && raw['dealPortal'] == true;
    final nextCredits = (iptvCredits ?? _iptvCredits).clamp(0, 1 << 30);
    final nextAdmin = isAdmin ?? _isAdmin;
    final nextMax = _parseMaxIptvPortals(raw);
    final nextMember = memberNumber ?? _memberNumber;
    if (nextScrape == _iptvScrape &&
        nextDeal == _dealPortal &&
        nextCredits == _iptvCredits &&
        nextAdmin == _isAdmin &&
        nextMax == _maxIptvPortals &&
        nextMember == _memberNumber) {
      return;
    }
    _iptvScrape = nextScrape;
    _dealPortal = nextDeal;
    _iptvCredits = nextCredits;
    _isAdmin = nextAdmin;
    _maxIptvPortals = nextMax;
    _memberNumber = nextMember;
    revision.value++;
  }

  /// Update credits only (after a deal).
  void setIptvCredits(int value) {
    final next = value.clamp(0, 1 << 30);
    if (next == _iptvCredits) return;
    _iptvCredits = next;
    revision.value++;
  }

  /// Cache opaque member id without touching feature flags.
  void setMemberNumber(int? value) {
    if (value == _memberNumber) return;
    _memberNumber = value;
    revision.value++;
  }

  /// Reset to all-off (sign-out / guest). Portal cap returns to default.
  void clear() {
    if (!_iptvScrape &&
        !_dealPortal &&
        _iptvCredits == 0 &&
        !_isAdmin &&
        _maxIptvPortals == defaultMaxIptvPortals &&
        _memberNumber == null) {
      return;
    }
    _iptvScrape = false;
    _dealPortal = false;
    _iptvCredits = 0;
    _isAdmin = false;
    _maxIptvPortals = defaultMaxIptvPortals;
    _memberNumber = null;
    revision.value++;
  }
}
