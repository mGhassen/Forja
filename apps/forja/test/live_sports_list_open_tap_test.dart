import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/list/list_open_mode.dart';

void main() {
  group('resolveKitListTapOpen', () {
    test('panel + wide → side panel', () {
      expect(
        resolveKitListTapOpen(
          openMode: 'panel',
          hasMatchOpenSurface: true,
          canShowSidePanel: true,
        ),
        KitListTapOpen.panel,
      );
    });

    test('panel + narrow → details (not silent)', () {
      expect(
        resolveKitListTapOpen(
          openMode: 'panel',
          hasMatchOpenSurface: true,
          canShowSidePanel: false,
        ),
        KitListTapOpen.details,
      );
    });

    test('details → details', () {
      expect(
        resolveKitListTapOpen(
          openMode: 'details',
          hasMatchOpenSurface: true,
          canShowSidePanel: true,
        ),
        KitListTapOpen.details,
      );
    });

    test('empty open with match surface defaults to panel path', () {
      expect(
        resolveKitListTapOpen(
          openMode: '',
          hasMatchOpenSurface: true,
          canShowSidePanel: true,
        ),
        KitListTapOpen.panel,
      );
    });

    test('unknown mode with match surface → details (not live openTap)', () {
      expect(
        resolveKitListTapOpen(
          openMode: 'whatever',
          hasMatchOpenSurface: true,
          canShowSidePanel: true,
        ),
        KitListTapOpen.details,
      );
    });

    test('label alias Side panel → panel', () {
      expect(
        resolveKitListTapOpen(
          openMode: 'Side panel',
          hasMatchOpenSurface: true,
          canShowSidePanel: true,
        ),
        KitListTapOpen.panel,
      );
    });

    test('IPTV without match surface still uses openTap', () {
      expect(
        resolveKitListTapOpen(
          openMode: '',
          hasMatchOpenSurface: false,
          canShowSidePanel: false,
        ),
        KitListTapOpen.openTap,
      );
    });
  });

  group('resolveListOpenMode', () {
    test('empty setting falls back to layout open', () async {
      final mode = await resolveListOpenMode(
        pluginId: '',
        openSettingId: null,
        layoutOpen: 'panel',
      );
      expect(mode, 'panel');
    });
  });
}
