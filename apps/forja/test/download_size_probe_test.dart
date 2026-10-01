import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_size_probe.dart';

void main() {
  test('sizeLabel formats exact and estimated sizes', () {
    expect(
      const DownloadSizeProbeResult(
        bytes: 1536,
        estimated: false,
        kind: 'http',
      ).sizeLabel,
      '1.50 KB',
    );
    expect(
      const DownloadSizeProbeResult(
        bytes: 1024 * 1024,
        estimated: true,
        kind: 'hls',
      ).sizeLabel,
      '~1.00 MB',
    );
    expect(
      const DownloadSizeProbeResult(
        bytes: 0,
        estimated: false,
        kind: 'unknown',
      ).sizeLabel,
      'Size unknown',
    );
  });
}
