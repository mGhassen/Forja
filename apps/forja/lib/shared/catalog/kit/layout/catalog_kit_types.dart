/// Catalog layout kit — normalized widget types declared by hub packs.
///
/// Packs use `kit.stack`, `kit.menu`, `kit.tabs`, `kit.list`, `kit.row` in
/// `layout` widgets. Legacy aliases (`stack`, `tabs`, `rail`, `host.my_list`)
/// normalize to the same slots for one release.
///
/// Domain data (My List, Live Sports, …) is a [kit.list] `source` id — not
/// product-named kit types.
abstract final class CatalogKitTypes {
  CatalogKitTypes._();

  static const stack = 'kit.stack';
  static const menu = 'kit.menu';
  static const tabs = 'kit.tabs';
  static const list = 'kit.list';
  static const row = 'kit.row';

  /// Normalize pack [rawType] (+ optional [spec] for legacy `tabs` style).
  static String normalize(String rawType, [Map<String, dynamic>? spec]) {
    final t = rawType.trim();
    if (t.isEmpty) return t;

    if (t == 'tabs') {
      final style = (spec?['style'] ?? '').toString();
      return style == 'kind' ? menu : tabs;
    }

    return switch (t) {
      'stack' || stack => stack,
      'menu' || menu => menu,
      'kit.tabs' || tabs => tabs,
      'host.my_list' || 'my_list' || list => list,
      'rail' || 'ranked' || row => row,
      _ => t,
    };
  }

  static bool isStack(String type) => normalize(type) == stack;

  static bool isCompositionRoot(Map<String, dynamic> spec) {
    final type = normalize((spec['type'] ?? '').toString(), spec);
    if (type == stack && spec['expand'] == true) return true;
    if (type == list) return true;
    return false;
  }

  static bool treeContains(
    Iterable<Map<String, dynamic>> roots, {
    required String slot,
    String? listSource,
  }) {
    var found = false;
    walkLayoutWidgets(roots, (spec) {
      if (found) return;
      final type = normalize((spec['type'] ?? '').toString(), spec);
      if (type != slot) return;
      if (slot == list && listSource != null) {
        final src = (spec['source'] ?? 'my_list').toString();
        if (src != listSource) return;
      }
      found = true;
    });
    return found;
  }
}

List<({String id, String label})> catalogKitItemsFromSpec(
  Map<String, dynamic> spec,
) {
  final raw = spec['items'] ?? spec['tabs'];
  if (raw is! List) return const [];
  final out = <({String id, String label})>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = (item['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    final label = (item['label'] ?? item['title'] ?? id).toString().trim();
    out.add((id: id, label: label.isEmpty ? id : label));
  }
  return out;
}

void walkLayoutWidgets(
  Iterable<Map<String, dynamic>> roots,
  void Function(Map<String, dynamic> spec) visit,
) {
  void walk(Map<String, dynamic> spec) {
    visit(spec);
    if (!CatalogKitTypes.isStack((spec['type'] ?? '').toString())) return;
    final children = spec['children'];
    if (children is! List) return;
    for (final child in children) {
      if (child is Map) walk(Map<String, dynamic>.from(child));
    }
  }

  for (final root in roots) {
    walk(root);
  }
}

Map<String, Map<String, dynamic>> layoutWidgetSpecIndex(
  Iterable<Map<String, dynamic>> roots,
) {
  final index = <String, Map<String, dynamic>>{};
  walkLayoutWidgets(roots, (spec) {
    final id = (spec['id'] ?? '').toString().trim();
    if (id.isNotEmpty) index[id] = spec;
  });
  return index;
}

void initLayoutTabSelections(
  Map<String, String> selections,
  Iterable<Map<String, dynamic>> roots,
) {
  walkLayoutWidgets(roots, (spec) {
    final type = CatalogKitTypes.normalize(
      (spec['type'] ?? '').toString(),
      spec,
    );
    if (type != CatalogKitTypes.menu && type != CatalogKitTypes.tabs) return;
    final id = (spec['id'] ?? '').toString().trim();
    if (id.isEmpty || selections.containsKey(id)) return;
    final def = spec['default']?.toString();
    if (def != null && def.isNotEmpty) {
      selections[id] = def;
    }
  });
}
