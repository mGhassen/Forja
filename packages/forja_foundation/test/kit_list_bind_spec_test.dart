import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/kit_list_bind.dart';

void main() {
  group('KitListBindSpec.fromJson', () {
    test('title is required', () {
      expect(KitListBindSpec.fromJson(null), isNull);
      expect(KitListBindSpec.fromJson('bind'), isNull);
      expect(KitListBindSpec.fromJson(<String, Object?>{}), isNull);
      expect(KitListBindSpec.fromJson({'title': '  '}), isNull);
      expect(KitListBindSpec.fromJson({'pickTitle': 'Pick'}), isNull);
    });

    test('defaults: remember + rebind on, strings empty, no excludes', () {
      final spec = KitListBindSpec.fromJson({'title': 'Open in'})!;
      expect(spec.title, 'Open in');
      expect(spec.pickTitle, '');
      expect(spec.pickTitleOrTitle, 'Open in');
      expect(spec.remember, isTrue);
      expect(spec.rebind, isTrue);
      expect(spec.excludeTypes, isEmpty);
      expect(spec.noMatch, '');
      expect(spec.cancel, '');
    });

    test('reads every declared field', () {
      final spec = KitListBindSpec.fromJson({
        'title': ' T ',
        'pickTitle': 'P',
        'hubLabel': 'H',
        'searchHint': 'S',
        'searchBrowseHint': 'SB',
        'searchEmpty': 'SE',
        'noMatch': 'NM {hub}',
        'noSearch': '{hub} NS',
        'noHub': 'NH',
        'noHandoff': 'NO',
        'noHandoffFor': 'NOF {hub}',
        'openIn': 'OI {hub}',
        'bestMatch': 'B',
        'untitled': 'U',
        'cancel': 'C',
        'remember': false,
        'rebind': false,
        'excludeTypes': ['foo', ' ', 'bar', 3],
      })!;
      expect(spec.title, 'T');
      expect(spec.pickTitle, 'P');
      expect(spec.pickTitleOrTitle, 'P');
      expect(spec.hubLabel, 'H');
      expect(spec.searchHint, 'S');
      expect(spec.searchBrowseHint, 'SB');
      expect(spec.searchEmpty, 'SE');
      expect(spec.noHub, 'NH');
      expect(spec.noHandoff, 'NO');
      expect(spec.bestMatch, 'B');
      expect(spec.untitled, 'U');
      expect(spec.cancel, 'C');
      expect(spec.remember, isFalse);
      expect(spec.rebind, isFalse);
      expect(spec.excludeTypes, ['foo', 'bar', '3']);
    });

    test('{hub} substitution', () {
      final spec = KitListBindSpec.fromJson({
        'title': 'T',
        'noMatch': 'No matches in {hub}',
        'noSearch': '{hub} cannot search',
        'noHandoffFor': 'No handoff for {hub} ({hub})',
        'openIn': 'Open in {hub}',
      })!;
      expect(spec.noMatchFor('Hub A'), 'No matches in Hub A');
      expect(spec.noSearchFor('Hub A'), 'Hub A cannot search');
      expect(spec.noHandoffForHub('X'), 'No handoff for X (X)');
      expect(spec.openInFor('X'), 'Open in X');
      expect(KitListBindSpec.substituteHub('plain', 'X'), 'plain');
    });

    test('non-bool remember / rebind fall back to true', () {
      final spec = KitListBindSpec.fromJson({
        'title': 'T',
        'remember': 'no',
        'rebind': 0,
      })!;
      expect(spec.remember, isTrue);
      expect(spec.rebind, isTrue);
    });
  });

  group('KitListAccessorySpec.parse', () {
    test('string accessory applies to every card kind', () {
      final pin = KitListAccessorySpec.parse('listPin')!;
      expect(pin.resolve('poster'), KitListAccessory.listPin);
      expect(pin.resolve('channel'), KitListAccessory.listPin);
      final fav = KitListAccessorySpec.parse('favorite')!;
      expect(fav.resolve('poster'), KitListAccessory.favorite);
    });

    test('map resolves by card kind with default fallback', () {
      final spec = KitListAccessorySpec.parse({
        'channel': 'favorite',
        'default': 'listPin',
      })!;
      expect(spec.resolve('channel'), KitListAccessory.favorite);
      expect(spec.resolve('poster'), KitListAccessory.listPin);
      expect(spec.resolve('event'), KitListAccessory.listPin);
    });

    test('map without default resolves null for unlisted kinds', () {
      final spec = KitListAccessorySpec.parse({'channel': 'favorite'})!;
      expect(spec.resolve('channel'), KitListAccessory.favorite);
      expect(spec.resolve('poster'), isNull);
    });

    test('unknown or empty declarations parse to null', () {
      expect(KitListAccessorySpec.parse(null), isNull);
      expect(KitListAccessorySpec.parse(''), isNull);
      expect(KitListAccessorySpec.parse('sparkle'), isNull);
      expect(KitListAccessorySpec.parse(<String, Object?>{}), isNull);
      expect(KitListAccessorySpec.parse({'poster': 'sparkle'}), isNull);
      expect(KitListAccessorySpec.parse(42), isNull);
    });

    test('unknown values inside a map are dropped, valid ones kept', () {
      final spec = KitListAccessorySpec.parse({
        'poster': 'sparkle',
        'channel': 'favorite',
      })!;
      expect(spec.resolve('poster'), isNull);
      expect(spec.resolve('channel'), KitListAccessory.favorite);
    });
  });
}
