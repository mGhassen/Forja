import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';

void main() {
  test('hides reqwest URL with credentials', () {
    const raw =
        'error sending request for url (http://visionplay.space/player_api.php?username=Gary&password=Gary1&action=get_live_categories)';
    final msg = IptvClient.formatEngineError(raw);
    expect(msg, 'Could not reach portal — check URL or network');
    expect(msg.contains('password'), isFalse);
    expect(msg.contains('Gary'), isFalse);
  });

  test('maps auth_failed', () {
    expect(
      IptvClient.formatEngineError('auth_failed'),
      'Login failed — check username and password',
    );
  });

  test('maps HTTP status', () {
    expect(IptvClient.formatEngineError('HTTP 403'), 'Portal returned HTTP 403');
  });

  test('keeps plain messages', () {
    expect(IptvClient.formatEngineError('Could not load catalog'), 'Could not load catalog');
  });
}
