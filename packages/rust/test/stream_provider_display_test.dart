import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/stream_provider_display.dart';

void main() {
  test('built-in providers use disguised player labels', () {
    expect(StreamProviderDisplay.playerLabel('vidsrc'), 'Prism');
    expect(StreamProviderDisplay.playerLabel('webstreamr'), 'Orbit');
    expect(StreamProviderDisplay.hasProfile('vidsrc'), isTrue);
  });

  test('nuvio scrapers reuse built-in disguise when ids match', () {
    expect(StreamProviderDisplay.playerLabel('nuvio:vidsrc'), 'Prism');
    expect(StreamProviderDisplay.playerLabel('nuvio:vidrock'), 'Summit');
  });

  test('unknown nuvio scrapers get stable disguised labels', () {
    final a = StreamProviderDisplay.playerLabel('nuvio:showbox');
    final b = StreamProviderDisplay.playerLabel('nuvio:showbox');
    expect(a, isNot('ShowBox'));
    expect(a, b);
  });

  test('nuvio flags come from contentLanguage', () {
    expect(
      StreamProviderDisplay.countryFlags(
        'nuvio:anime-sama',
        contentLanguage: ['fr'],
      ),
      '🇫🇷',
    );
    expect(
      StreamProviderDisplay.countryFlags(
        'nuvio:onlykdrama',
        contentLanguage: ['ko'],
      ),
      '🇰🇷',
    );
  });

  test('unknown providers fall back to real name', () {
    expect(StreamProviderDisplay.playerLabel('custom', fallbackName: 'Demo'), 'Demo');
    expect(StreamProviderDisplay.hasProfile('custom'), isFalse);
  });

  test('player list label combines flag and friendly name', () {
    expect(
      StreamProviderDisplay.playerListLabel('vidlink'),
      '🌐 Echo',
    );
  });
}
