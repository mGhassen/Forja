/// Display names from pack `props.catalogs` (`["PPV", "ESPN"]` or `{name}`).
List<String> eventCatalogLabels(Object? raw) {
  if (raw is! List || raw.isEmpty) return const [];
  final out = <String>[];
  final seen = <String>{};
  for (final item in raw) {
    final label = switch (item) {
      final String s => s.trim(),
      final Map m =>
        (m['name'] ?? m['label'] ?? m['id'] ?? '').toString().trim(),
      _ => '',
    };
    if (label.isEmpty) continue;
    if (!seen.add(label.toLowerCase())) continue;
    out.add(label);
  }
  return out;
}
