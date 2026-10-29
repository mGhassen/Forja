import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/shell/split_layout.dart';
import 'package:forja/shared/engine/runtime/search/host_search_wire.dart';
import 'package:forja/shell/chrome/kit_categories_mobile_sheet.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/mobile_chrome_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';

const _phonePortrait = Size(411, 914);
const _phoneLandscape = Size(914, 411);

Widget _host(
  ShellProfile profile,
  Size size,
  Widget child, {
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, viewInsets: viewInsets),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: Scaffold(body: child),
      ),
    ),
  );
}

Future<void> _surface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

const _categories = [
  (id: 'c1', label: 'Alpha Category'),
  (id: 'c2', label: 'Beta'),
  (id: 'c3', label: 'Gamma Long Category Name'),
  (id: 'c4', label: 'Delta'),
];

void main() {
  group('settingsUseSplitLayout', () {
    Future<bool> split(WidgetTester tester, ShellProfile p, Size s) async {
      late bool out;
      await _surface(tester, s);
      await tester.pumpWidget(
        _host(
          p,
          s,
          Builder(
            builder: (context) {
              out = settingsUseSplitLayout(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return out;
    }

    testWidgets('phone landscape stays single-pane', (tester) async {
      expect(await split(tester, ShellProfile.mobile, _phoneLandscape), isFalse);
      expect(await split(tester, ShellProfile.mobile, _phonePortrait), isFalse);
    });

    testWidgets('tablet, desktop and TV keep the split at width', (
      tester,
    ) async {
      const tablet = Size(1280, 800);
      expect(await split(tester, ShellProfile.mobile, tablet), isTrue);
      expect(await split(tester, ShellProfile.desktop, tablet), isTrue);
      expect(
        await split(tester, ShellProfile.tv, const Size(1920, 1080)),
        isTrue,
      );
    });
  });

  group('Categories mobile sheet', () {
    Future<String?> open(
      WidgetTester tester,
      Future<void> Function() act,
    ) async {
      await _surface(tester, _phonePortrait);
      String? result = 'unset';
      await tester.pumpWidget(
        _host(
          ShellProfile.mobile,
          _phonePortrait,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showKitCategoriesMobileSheet(
                  context: context,
                  categories: _categories,
                  selectedId: 'c2',
                  allValue: '__all__',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('chips show every category and pick returns its id', (
      tester,
    ) async {
      final picked = await open(tester, () async {
        expect(find.text('Categories'), findsOneWidget);
        expect(find.byType(ForjaShellChip), findsNWidgets(5));
        expect(find.text('Gamma Long Category Name'), findsOneWidget);
        final beta = tester.widget<ForjaShellChip>(
          find.widgetWithText(ForjaShellChip, 'Beta'),
        );
        expect(beta.selected, isTrue);
        await tester.tap(find.text('Gamma Long Category Name'));
      });
      expect(picked, 'c3');
    });

    testWidgets('All returns the all sentinel', (tester) async {
      final picked = await open(tester, () async {
        await tester.tap(find.text('All'));
      });
      expect(picked, '__all__');
    });

    testWidgets('close button dismisses without a pick', (tester) async {
      final picked = await open(tester, () async {
        await tester.tap(find.byIcon(Icons.close_rounded));
      });
      expect(picked, isNull);
    });
  });

  group('Search on phone landscape', () {
    Widget page() => KitSearchPage(
      hintText: 'Search Synthetic…',
      tvTabId: 'synthetic_tab',
      onSearch: (_) async => const [],
      onOpen: (_) {},
      loadRecommendations: ({required query, required results}) async =>
          const [],
    );

    testWidgets('keyboard open: no overflow, compact field font', (
      tester,
    ) async {
      await _surface(tester, _phoneLandscape);
      await tester.pumpWidget(
        _host(
          ShellProfile.mobile,
          _phoneLandscape,
          page(),
          viewInsets: const EdgeInsets.only(bottom: 260),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.style?.fontSize, MobileChromeTokens.searchQueryFontSize);
      // Phone types on focus — the field is editable, not browse-only.
      expect(field.readOnly, isFalse);
    });
  });
}
