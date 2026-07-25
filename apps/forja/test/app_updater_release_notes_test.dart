import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/app_updater_release_notes.dart';

void main() {
  group('AppUpdaterReleaseNotes.isNewerVersion', () {
    test('detects newer patch/minor/major', () {
      expect(AppUpdaterReleaseNotes.isNewerVersion('1.2.281', '1.2.283'), isTrue);
      expect(AppUpdaterReleaseNotes.isNewerVersion('1.2.283', '1.2.281'), isFalse);
      expect(AppUpdaterReleaseNotes.isNewerVersion('1.2.283', '1.2.283'), isFalse);
      expect(AppUpdaterReleaseNotes.isNewerVersion('1.1.0', '1.2.0'), isTrue);
    });
  });

  group('AppUpdaterReleaseNotes.cleanBody', () {
    test('drops Full Changelog-only auto notes', () {
      expect(
        AppUpdaterReleaseNotes.cleanBody(
          'Full Changelog: https://github.com/mGhassen/Forja/compare/v1.2.282...v1.2.283',
        ),
        isEmpty,
      );
      expect(
        AppUpdaterReleaseNotes.cleanBody(
          '**Full Changelog**: https://github.com/mGhassen/Forja/compare/v1.2.282...v1.2.283',
        ),
        isEmpty,
      );
    });

    test('keeps thematic bullets and strips leading H1', () {
      final cleaned = AppUpdaterReleaseNotes.cleanBody('''
# 1.2.281 - Dabaghin

### Features
- **Add:** Web login from the desktop app.
''');
      expect(cleaned, contains('### Features'));
      expect(cleaned, contains('**Add:** Web login'));
      expect(cleaned.startsWith('# '), isFalse);
    });
  });

  group('AppUpdaterReleaseNotes.collect', () {
    test('caps at maxChangelogVersions', () {
      final releases = <ReleaseNotesEntry>[
        for (var i = 1; i <= 20; i++)
          ReleaseNotesEntry(
            version: '1.2.$i',
            body: '### Features\n- **Add:** Note $i.',
          ),
      ];
      final collected = AppUpdaterReleaseNotes.collect(
        currentVersion: '1.2.0',
        latestVersion: '1.2.20',
        releases: releases,
      );
      expect(collected, hasLength(AppUpdaterReleaseNotes.maxChangelogVersions));
      expect(collected.first.version, '1.2.20');
      expect(collected.last.version, '1.2.5');
    });
  });

  group('AppUpdaterReleaseNotes.aggregate', () {
    test('joins every release newer than installed, newest first', () {
      final notes = AppUpdaterReleaseNotes.aggregate(
        currentVersion: '1.2.264',
        releases: const [
          ReleaseNotesEntry(
            version: '1.2.283',
            body: 'Full Changelog: v1.2.282...v1.2.283',
          ),
          ReleaseNotesEntry(
            version: '1.2.281',
            body: '''
# 1.2.281 - Dabaghin

### Live & IPTV
- **Fix:** Popular live events stay playable.
''',
          ),
          ReleaseNotesEntry(
            version: '1.2.267',
            body: '''
### UI
- **Change:** Shell icons are larger.
''',
          ),
          ReleaseNotesEntry(
            version: '1.2.264',
            body: '''
### Sources
- **Add:** Should not appear (same as installed).
''',
          ),
          ReleaseNotesEntry(
            version: '1.2.200',
            body: '''
### Player
- **Fix:** Older than installed - must not appear.
''',
          ),
        ],
      );

      expect(notes, contains('# 1.2.281'));
      expect(notes, contains('# 1.2.267'));
      expect(notes, isNot(contains('1.2.283')));
      expect(notes, isNot(contains('Should not appear')));
      expect(notes, isNot(contains('Older than installed')));
      expect(notes.indexOf('1.2.281'), lessThan(notes.indexOf('1.2.267')));
    });

    test('single contributing release omits version H1', () {
      final notes = AppUpdaterReleaseNotes.aggregate(
        currentVersion: '1.2.280',
        releases: const [
          ReleaseNotesEntry(
            version: '1.2.281',
            body: '''
# 1.2.281 - Dabaghin

### Features
- **Add:** Only this version.
''',
          ),
        ],
      );

      expect(notes.startsWith('# '), isFalse);
      expect(notes, contains('### Features'));
      expect(notes, contains('Only this version'));
    });

    test('skips prerelease and draft entries', () {
      final notes = AppUpdaterReleaseNotes.aggregate(
        currentVersion: '1.2.0',
        releases: const [
          ReleaseNotesEntry(
            version: '1.2.2',
            body: '### Features\n- **Add:** Stable notes.',
          ),
          ReleaseNotesEntry(
            version: '1.2.3',
            body: '### Features\n- **Add:** Beta.',
            prerelease: true,
          ),
          ReleaseNotesEntry(
            version: '1.2.4',
            body: '### Features\n- **Add:** Draft.',
            draft: true,
          ),
        ],
      );

      expect(notes, contains('Stable notes'));
      expect(notes, isNot(contains('Beta')));
      expect(notes, isNot(contains('Draft')));
    });
  });
}
