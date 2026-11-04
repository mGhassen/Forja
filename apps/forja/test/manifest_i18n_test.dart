import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/manifest_i18n.dart';
import 'package:forja/shared/services/app/app_locale.dart';
import 'package:forja/shared/utils/byte_units.dart';

Map<String, dynamic> _plugin() => {
  'id': 'tmdb',
  'name': 'Home',
  'entry': 'tmdb.js',
  'description': 'TMDB movie / TV hub',
  'nav': {'label': 'Home', 'icon': 'icons/nav.png'},
  'settings': {
    'group': 'Details',
    'fields': [
      {
        'id': 'episodeView',
        'label': 'Episode list',
        'default': 'cards',
        'options': [
          {'id': 'cards', 'label': 'Cards'},
          {'id': 'chips', 'label': 'Number chips'},
        ],
      },
    ],
  },
  'i18n': {
    'fr': {
      'Home': 'Accueil',
      'Details': 'Détails',
      'Episode list': 'Liste des épisodes',
      'Cards': 'Cartes',
      'TMDB movie / TV hub': 'Hub films et séries TMDB',
    },
  },
};

void main() {
  tearDown(() => AppLocale.notifier.value = null);

  test('translates text keys and leaves ids and stored values alone', () {
    final p = _plugin();
    final out = localizeManifestText(p, p['i18n'], 'fr');
    expect(out['name'], 'Accueil');
    expect(out['description'], 'Hub films et séries TMDB');
    expect((out['nav'] as Map)['label'], 'Accueil');
    expect((out['nav'] as Map)['icon'], 'icons/nav.png');
    final settings = out['settings'] as Map;
    expect(settings['group'], 'Détails');
    final field = (settings['fields'] as List).single as Map;
    expect(field['id'], 'episodeView');
    expect(field['default'], 'cards');
    expect(field['label'], 'Liste des épisodes');
    final options = field['options'] as List;
    expect((options[0] as Map)['id'], 'cards');
    expect((options[0] as Map)['label'], 'Cartes');
    // No table entry: the English text stays.
    expect((options[1] as Map)['label'], 'Number chips');
  });

  test('English or a language without a table changes nothing', () {
    final p = _plugin();
    expect(localizeManifestText(p, p['i18n'], 'en'), isEmpty);
    expect(localizeManifestText(p, p['i18n'], 'de'), isEmpty);
    expect(localizeManifestText(p, null, 'fr'), isEmpty);
  });

  test('EnginePlugin follows the app language and saves the manifest text', () {
    AppLocale.notifier.value = const Locale('fr');
    final fr = EnginePlugin.fromJson(_plugin());
    expect(fr.name, 'Accueil');
    expect(fr.nav?['label'], 'Accueil');
    // What is written to disk is the manifest's own text.
    final saved = fr.toJson();
    expect(saved['name'], 'Home');
    expect((saved['nav'] as Map)['label'], 'Home');
    expect((saved['settings'] as Map)['group'], 'Details');

    AppLocale.notifier.value = const Locale('en');
    final en = EnginePlugin.fromJson(saved);
    expect(en.name, 'Home');
    expect(en.nav?['label'], 'Home');
    AppLocale.notifier.value = const Locale('fr');
    expect(EnginePlugin.fromJson(saved).name, 'Accueil');
  });

  test('byte sizes use the app language', () {
    AppLocale.notifier.value = const Locale('en');
    expect(ByteUnits.format(1.5, 3, 2), '1.50 GB');
    AppLocale.notifier.value = const Locale('fr');
    expect(ByteUnits.format(1.5, 3, 2), '1,50 Go');
    expect(ByteUnits.format(0, 0, 0), '0 o');
  });
}
