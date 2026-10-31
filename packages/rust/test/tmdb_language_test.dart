import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  tearDown(() {
    TmdbLanguage.resolve = null;
  });

  test('normalize keeps ll and ll-CC in TMDB spelling', () {
    expect(TmdbLanguage.normalize('fr'), 'fr');
    expect(TmdbLanguage.normalize('FR-fr'), 'fr-FR');
    expect(TmdbLanguage.normalize(' pt_BR '), 'pt-BR');
  });

  test('normalize falls back for anything else', () {
    expect(TmdbLanguage.normalize(null), 'en-US');
    expect(TmdbLanguage.normalize(''), 'en-US');
    expect(TmdbLanguage.normalize('french'), 'en-US');
    expect(TmdbLanguage.normalize('fr-FRA'), 'en-US');
    expect(TmdbLanguage.normalize('zh-Hans-CN'), 'en-US');
  });

  test('current follows the resolver, and falls back without one', () {
    expect(TmdbLanguage.current, 'en-US');
    TmdbLanguage.resolve = () => 'fr-FR';
    expect(TmdbLanguage.current, 'fr-FR');
    expect(TmdbLanguage.code, 'fr');
  });

  test('applyTo adds language to a French request', () {
    TmdbLanguage.resolve = () => 'fr-FR';
    expect(TmdbLanguage.applyTo('movie/8587'), 'movie/8587?language=fr-FR');
    expect(
      TmdbLanguage.applyTo('tv/1399?append_to_response=images'),
      'tv/1399?append_to_response=images&language=fr-FR',
    );
  });

  test('applyTo does not mistake with_original_language for language', () {
    TmdbLanguage.resolve = () => 'fr-FR';
    expect(
      TmdbLanguage.applyTo('discover/tv?with_original_language=ko'),
      'discover/tv?with_original_language=ko&language=fr-FR',
    );
  });

  test('applyTo leaves a request that already sets a language', () {
    TmdbLanguage.resolve = () => 'fr-FR';
    expect(
      TmdbLanguage.applyTo('movie/1?language=de-DE&page=2'),
      'movie/1?language=de-DE&page=2',
    );
    expect(
      TmdbLanguage.applyTo('movie/1?page=2&language=de-DE'),
      'movie/1?page=2&language=de-DE',
    );
  });

  test('applyTo leaves English requests exactly as they were', () {
    expect(TmdbLanguage.applyTo('movie/8587'), 'movie/8587');
    TmdbLanguage.resolve = () => 'en-GB';
    expect(TmdbLanguage.applyTo('movie/8587'), 'movie/8587?language=en-GB');
    TmdbLanguage.resolve = () => 'en-US';
    expect(TmdbLanguage.applyTo('movie/8587?x=1'), 'movie/8587?x=1');
  });

  test('imageLanguages puts the app language first', () {
    expect(TmdbLanguage.imageLanguages, 'en,null');
    TmdbLanguage.resolve = () => 'fr-FR';
    expect(TmdbLanguage.imageLanguages, 'fr,en,null');
    TmdbLanguage.resolve = () => 'en-GB';
    expect(TmdbLanguage.imageLanguages, 'en,null');
  });
}
