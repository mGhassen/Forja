import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/packs/pack_prompt_pane.dart';

void main() {
  group('packPromptSourceLabel', () {
    test('official row shows the host only', () {
      expect(
        packPromptSourceLabel(
          'https://packs.example/hubs/any/manifest.json',
          official: true,
        ),
        'packs.example',
      );
    });

    test('community row shows host and a Community source tag', () {
      expect(
        packPromptSourceLabel(
          'https://Raw.Somewhere.Example/u/r/manifest.json',
          official: false,
        ),
        'raw.somewhere.example · Community source',
      );
    });

    test('local checkout shows Local folder', () {
      expect(
        packPromptSourceLabel(
          '/Users/me/forja-packs/manifest.json',
          official: false,
        ),
        'Local folder · Community source',
      );
      expect(
        packPromptSourceLabel('file:///tmp/p/manifest.json', official: true),
        'Local folder',
      );
    });
  });
}
