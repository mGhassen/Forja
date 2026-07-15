import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/providers/display/stream_provider_display.dart';

void main() {
  test('built-in providers use real player labels', () {
    expect(StreamProviderDisplay.playerLabel('vidsrc'), 'VSEmbed');
    expect(StreamProviderDisplay.playerLabel('vidsrcwin'), 'VidSrc');
    expect(StreamProviderDisplay.playerLabel('webstreamr'), 'WebStreamr');
    expect(StreamProviderDisplay.hasProfile('vidsrc'), isTrue);
    expect(StreamProviderDisplay.hasProfile('vidsrcwin'), isTrue);
  });

  test('nuvio scrapers reuse built-in names when ids match', () {
    expect(StreamProviderDisplay.playerLabel('nuvio:vidsrc'), 'VSEmbed');
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

  test('unknown providers fall back to real name', () {
    expect(StreamProviderDisplay.playerLabel('custom', fallbackName: 'Demo'), 'Demo');
    expect(StreamProviderDisplay.hasProfile('custom'), isFalse);
  });

  test('server list label is name only — no region flags', () {
    expect(StreamProviderDisplay.playerListLabel('vidlink'), 'VidLink');
    expect(StreamProviderDisplay.playerListLabel('service111477'), '111477');
  });

  test('flagForCountry remains for torrent language filters', () {
    expect(StreamProviderDisplay.flagForCountry('en'), '🇺🇸');
    expect(StreamProviderDisplay.flagForCountry('fr'), '🇫🇷');
  });

  test('flagsForText prefers emoji already in the stream title', () {
    expect(
      StreamProviderDisplay.flagsForText('WebStreamr 🇩🇪\n🔗 KinoGer'),
      '🇩🇪',
    );
  });

  test('flagsForText detects language tokens when no emoji present', () {
    expect(
      StreamProviderDisplay.flagsForText('GERMAN DL 1080p HEVC'),
      '🇩🇪',
    );
    expect(
      StreamProviderDisplay.flagsForText('French VOSTFR stream'),
      '🇫🇷',
    );
  });
}
