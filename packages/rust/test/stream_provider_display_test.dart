import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/stream_provider_display.dart';

void main() {
  test('built-in providers use real player labels', () {
    expect(StreamProviderDisplay.playerLabel('vidsrc'), 'Vidsrc');
    expect(StreamProviderDisplay.playerLabel('webstreamr'), 'WebStreamr');
    expect(StreamProviderDisplay.hasProfile('vidsrc'), isTrue);
  });

  test('nuvio scrapers reuse built-in names when ids match', () {
    expect(StreamProviderDisplay.playerLabel('nuvio:vidsrc'), 'Vidsrc');
    expect(StreamProviderDisplay.playerLabel('nuvio:vidrock'), 'VidRock');
  });

  test('unknown nuvio scrapers use fallback or title-cased id', () {
    expect(
      StreamProviderDisplay.playerLabel(
        'nuvio:showbox',
        fallbackName: 'ShowBox',
      ),
      'ShowBox',
    );
    expect(
      StreamProviderDisplay.playerLabel('nuvio:showbox'),
      'Showbox',
    );
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

  test('player list label combines flag and real name', () {
    expect(
      StreamProviderDisplay.playerListLabel('vidlink'),
      '🌐 VidLink',
    );
  });
}
