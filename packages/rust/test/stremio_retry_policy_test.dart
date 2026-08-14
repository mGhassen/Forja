import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('timeout errors are not retried', () {
    expect(stremioErrorIsTimeout(Exception('timeout')), isTrue);
    expect(stremioErrorIsTimeout('Connection timed out'), isTrue);
    expect(stremioErrorIsTimeout('deadline has elapsed'), isTrue);
    expect(stremioErrorIsTimeout('HTTP 503'), isFalse);
  });

  test('4xx except 429 is no-retry; 403/429/5xx cooldown', () {
    expect(stremioStatusIsNoRetry(404), isTrue);
    expect(stremioStatusIsNoRetry(403), isTrue);
    expect(stremioStatusIsNoRetry(429), isFalse);
    expect(stremioStatusIsNoRetry(503), isFalse);
    expect(stremioStatusShouldCooldown(403), isTrue);
    expect(stremioStatusShouldCooldown(429), isTrue);
    expect(stremioStatusShouldCooldown(502), isTrue);
    expect(stremioStatusShouldCooldown(404), isFalse);
    expect(stremioStatusShouldCooldown(200), isFalse);
  });
}
