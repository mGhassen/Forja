/// Pack manifest text in the app language.
///
/// A manifest may carry `i18n: { "fr": { "<English text>": "<French text>" } }`.
/// The English text is the key, so a missing language or a missing entry shows
/// the manifest's own text unchanged.
library;

/// Manifest keys inside `settings` whose values are text shown to the user.
const _textKeys = {
  'label',
  'subtitle',
  'group',
  'placeholder',
  'hint',
  'description',
  'title',
};

/// The parts of a plugin entry that show text: [name], [description], `nav`
/// and `settings`. Everything else (ids, options' stored values, URLs) is
/// returned untouched by [localizeManifestText].
const manifestTextKeys = ['name', 'description', 'nav', 'settings'];

/// Returns [plugin]'s text fields translated into [lang], or an empty map when
/// there is nothing to translate.
Map<String, dynamic> localizeManifestText(
  Map<String, dynamic> plugin,
  Object? i18n,
  String lang,
) {
  if (i18n is! Map) return const {};
  final table = i18n[lang];
  if (table is! Map || table.isEmpty) return const {};

  String tr(String s) {
    final t = table[s];
    return t is String && t.isNotEmpty ? t : s;
  }

  Object? walk(Object? node, {required bool translateHere}) {
    if (node is Map) {
      return {
        for (final e in node.entries)
          e.key: e.value is String
              ? (translateHere && _textKeys.contains(e.key)
                    ? tr(e.value as String)
                    : e.value)
              : walk(e.value, translateHere: true),
      };
    }
    if (node is List) {
      return [for (final e in node) walk(e, translateHere: true)];
    }
    return node;
  }

  final out = <String, dynamic>{};
  for (final key in ['name', 'description']) {
    final v = plugin[key];
    if (v is String) out[key] = tr(v.trim());
  }
  final nav = plugin['nav'];
  if (nav is Map) out['nav'] = walk(nav, translateHere: true);
  final settings = plugin['settings'];
  if (settings is Map) out['settings'] = walk(settings, translateHere: true);
  return out;
}
