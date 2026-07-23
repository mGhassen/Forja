import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/stream_media_classifier.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('StreamMediaClassifier.classifyBytes', () {
    test('PNG+TS after IEND → pngWrapTs', () {
      final raw = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0, 0, 0, 0, 0, 0, 0, 0,
        0x49, 0x45, 0x4E, 0x44, 0, 0, 0, 0,
        0x47,
        ...List.filled(187, 0),
        0x47,
      ];
      expect(pngWrapsMpegTs(raw), isTrue);
      expect(
        StreamMediaClassifier.classifyBytes(raw),
        StreamMediaClass.pngWrapTs,
      );
    });

    test('tiny PNG Range decoy → pngWrapTs', () {
      final raw = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        1, 2, 3, 4,
      ];
      expect(raw.length < 512, isTrue);
      expect(
        StreamMediaClassifier.classifyBytes(raw),
        StreamMediaClass.pngWrapTs,
      );
    });

    test('large PNG without TS → imageNoTs', () {
      final raw = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        ...List.filled(600, 1),
      ];
      expect(pngWrapsMpegTs(raw), isFalse);
      expect(
        StreamMediaClassifier.classifyBytes(raw),
        StreamMediaClass.imageNoTs,
      );
    });

    test('MPEG-TS sync → plainMedia', () {
      final raw = <int>[
        0x47,
        ...List.filled(187, 0),
        0x47,
        ...List.filled(187, 0),
      ];
      expect(
        StreamMediaClassifier.classifyBytes(raw),
        StreamMediaClass.plainMedia,
      );
    });
  });
}
