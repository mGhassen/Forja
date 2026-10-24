/// kit.list `open: 'bind'` — pack-declared hub-bind sheet copy and the
/// per-card accessory a list paints. Protocol types only: the pack declares
/// every string; the host paints them as-is and substitutes `{hub}`.
library;

/// Copy + policy for the hub-bind sheet a `kit.list` opens on tap when the
/// pack declares `open: 'bind'`. Null from [fromJson] when `title` is missing.
class KitListBindSpec {
  const KitListBindSpec({
    required this.title,
    this.pickTitle = '',
    this.hubLabel = '',
    this.searchHint = '',
    this.searchBrowseHint = '',
    this.searchEmpty = '',
    this.noMatch = '',
    this.noSearch = '',
    this.noHub = '',
    this.noHandoff = '',
    this.noHandoffFor = '',
    this.openIn = '',
    this.bestMatch = '',
    this.untitled = '',
    this.cancel = '',
    this.remember = true,
    this.rebind = true,
    this.excludeTypes = const [],
  });

  /// Placeholder replaced by the hub label in `{hub}` strings.
  static const String hubToken = '{hub}';

  /// Sheet title on tap (required).
  final String title;

  /// Sheet title on long-press rebind. Empty → [title].
  final String pickTitle;

  /// Label above the hub chips.
  final String hubLabel;

  /// Search field hint (typing surfaces).
  final String searchHint;

  /// Search field placeholder while browsing on leanback (focus ≠ edit).
  final String searchBrowseHint;

  /// Shown when the query is empty.
  final String searchEmpty;

  /// Shown when a hub search returns nothing. `{hub}` → hub label.
  final String noMatch;

  /// Shown when the picked hub cannot search. `{hub}` → hub label.
  final String noSearch;

  /// Toast when no installed hub can open the row.
  final String noHub;

  /// Toast when the picked match carries no open handoff.
  final String noHandoff;

  /// Toast when the picked hub has no open handoff for the row. `{hub}` → hub label.
  final String noHandoffFor;

  /// Confirm row for a hub that can open the row directly. `{hub}` → hub label.
  final String openIn;

  /// Badge on the top-ranked search hit.
  final String bestMatch;

  /// Fallback name for rows without a title.
  final String untitled;

  /// Dismiss button.
  final String cancel;

  /// Persist the chosen hub on the row so the next tap opens it directly.
  final bool remember;

  /// Long-press / secondary click re-opens the sheet to pick another hub.
  final bool rebind;

  /// Plugin type tokens that never appear as hub candidates.
  final List<String> excludeTypes;

  String get pickTitleOrTitle => pickTitle.isEmpty ? title : pickTitle;

  String noMatchFor(String hub) => substituteHub(noMatch, hub);
  String noSearchFor(String hub) => substituteHub(noSearch, hub);
  String noHandoffForHub(String hub) => substituteHub(noHandoffFor, hub);
  String openInFor(String hub) => substituteHub(openIn, hub);

  /// Replace every `{hub}` in [template] with [hub].
  static String substituteHub(String template, String hub) =>
      template.replaceAll(hubToken, hub);

  static KitListBindSpec? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = _string(raw['title']);
    if (title.isEmpty) return null;
    return KitListBindSpec(
      title: title,
      pickTitle: _string(raw['pickTitle']),
      hubLabel: _string(raw['hubLabel']),
      searchHint: _string(raw['searchHint']),
      searchBrowseHint: _string(raw['searchBrowseHint']),
      searchEmpty: _string(raw['searchEmpty']),
      noMatch: _string(raw['noMatch']),
      noSearch: _string(raw['noSearch']),
      noHub: _string(raw['noHub']),
      noHandoff: _string(raw['noHandoff']),
      noHandoffFor: _string(raw['noHandoffFor']),
      openIn: _string(raw['openIn']),
      bestMatch: _string(raw['bestMatch']),
      untitled: _string(raw['untitled']),
      cancel: _string(raw['cancel']),
      remember: raw['remember'] is bool ? raw['remember'] as bool : true,
      rebind: raw['rebind'] is bool ? raw['rebind'] as bool : true,
      excludeTypes: _strings(raw['excludeTypes']),
    );
  }

  static String _string(Object? v) => (v ?? '').toString().trim();

  static List<String> _strings(Object? v) {
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (_string(e).isNotEmpty) _string(e),
    ];
  }
}

/// Corner control a kit.list paints on each card.
enum KitListAccessory {
  /// Watch-status pin (add to list).
  listPin,

  /// Channel favorite star.
  favorite;

  static KitListAccessory? parse(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    switch (v) {
      case 'listpin':
      case 'list_pin':
      case 'pin':
        return KitListAccessory.listPin;
      case 'favorite':
      case 'favourite':
        return KitListAccessory.favorite;
    }
    return null;
  }
}

/// Pack `accessory` on a kit.list — one accessory for every card, or a map
/// keyed by resolved card kind with an optional `default`:
///
/// ```json
/// "accessory": "listPin"
/// "accessory": { "channel": "favorite", "default": "listPin" }
/// ```
class KitListAccessorySpec {
  const KitListAccessorySpec._({
    this.single,
    this.byCardKind = const {},
    this.fallback,
  });

  final KitListAccessory? single;
  final Map<String, KitListAccessory> byCardKind;
  final KitListAccessory? fallback;

  static const String defaultKey = 'default';

  /// Null when nothing valid is declared.
  static KitListAccessorySpec? parse(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final map = <String, KitListAccessory>{};
      KitListAccessory? fallback;
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        final value = KitListAccessory.parse(entry.value);
        if (key.isEmpty || value == null) continue;
        if (key.toLowerCase() == defaultKey) {
          fallback = value;
        } else {
          map[key] = value;
        }
      }
      if (map.isEmpty && fallback == null) return null;
      return KitListAccessorySpec._(byCardKind: map, fallback: fallback);
    }
    final single = KitListAccessory.parse(raw);
    if (single == null) return null;
    return KitListAccessorySpec._(single: single);
  }

  /// Accessory for a card of [cardKind] (`poster`, `channel`, …).
  KitListAccessory? resolve(String cardKind) {
    if (single != null) return single;
    final k = cardKind.trim();
    return byCardKind[k] ?? fallback;
  }
}
