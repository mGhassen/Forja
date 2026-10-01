import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/list/list_open_mode.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void main() {
  group('kitListCanShowSidePanel', () {
    test('needs chrome', () {
      expect(
        kitListCanShowSidePanel(
          hasChrome: false,
          layoutWidth: 1200,
        ),
        isFalse,
      );
    });

    test('wide desktop docks', () {
      expect(
        kitListCanShowSidePanel(
          hasChrome: true,
          layoutWidth: ShellTokens.sidePanelWideBreakpoint,
        ),
        isTrue,
      );
    });

    test('narrow desktop falls back', () {
      expect(
        kitListCanShowSidePanel(
          hasChrome: true,
          layoutWidth: ShellTokens.sidePanelWideBreakpoint - 1,
        ),
        isFalse,
      );
    });

    test('Android TV docks even when the list strip is narrow', () {
      expect(
        kitListCanShowSidePanel(
          hasChrome: true,
          layoutWidth: 600,
          androidTv: true,
        ),
        isTrue,
      );
    });
  });

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
