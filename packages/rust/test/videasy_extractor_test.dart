import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/videasy_extractor.dart';

void main() {
  test('doubleEncodeTitle double-encodes spaces', () {
    expect(
      VideasyExtractor.doubleEncodeTitle('Fight Club'),
      'Fight%2520Club',
    );
  });

  test('yearFromReleaseDate returns first four chars', () {
    expect(VideasyExtractor.yearFromReleaseDate('1999-10-15'), '1999');
    expect(VideasyExtractor.yearFromReleaseDate(''), isNull);
  });
}
