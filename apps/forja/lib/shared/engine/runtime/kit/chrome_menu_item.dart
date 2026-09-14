/// Pack-declared top-bar menu tab (`filters.menus[]`).
class ChromeMenuItem {
  const ChromeMenuItem({
    required this.id,
    required this.label,
    this.filter,
    this.hideTypeFilterRails = false,
  });

  final String id;
  final String label;
  final Map<String, dynamic>? filter;

  /// When selected, hide layout rails marked `hideWhenTypeFilter`.
  final bool hideTypeFilterRails;
}
