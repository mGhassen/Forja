import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/forja_scrollbar.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android TV does not auto-paint scrollbar on every scrollable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const ForjaScrollBehavior(),
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ShellPaintScope(
            useTvFocus: true,
            scaleOnHover: false,
            focusStyled: (_, {required focused}) => focused,
            usesTvDensity: true,
            child: ListView(
              children: List.generate(
                40,
                (i) => SizedBox(height: 80, child: Text('row $i')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RawScrollbar), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('LiveTvScrollbar paints green thumb on TV density', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ShellPaintScope(
            useTvFocus: true,
            scaleOnHover: false,
            focusStyled: (_, {required focused}) => focused,
            usesTvDensity: true,
            child: LiveTvScrollbar(
              controller: scroll,
              child: ListView(
                controller: scroll,
                children: List.generate(
                  40,
                  (i) => SizedBox(height: 80, child: Text('row $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RawScrollbar), findsOneWidget);
    final bar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
    expect(bar.thumbVisibility, isNull);
    expect(bar.interactive, isFalse);
    expect(bar.thumbColor, ForjaScrollbarStyle.thumbColor);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop still paints green RawScrollbar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const ForjaScrollBehavior(),
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: ListView(
            children: List.generate(
              40,
              (i) => SizedBox(height: 80, child: Text('row $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RawScrollbar), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
