import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/platform/youtube_stream_service.dart';

void main() {
  test('isGeoblockedError detects country restriction messages', () {
    expect(
      YoutubeStreamService.isGeoblockedError(
        "Video 'uaDeobqouGQ' is unplayable.\n"
        'Reason: The uploader has not made this video available in your country',
      ),
      isTrue,
    );
    expect(
      YoutubeStreamService.isGeoblockedError('Video is geo-restricted'),
      isTrue,
    );
    expect(
      YoutubeStreamService.isGeoblockedError('Sign in to confirm your age'),
      isFalse,
    );
  });
}
