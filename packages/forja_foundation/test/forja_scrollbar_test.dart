import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/forja_scrollbar.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ShellTokens.nativeAndroidTvDetected = false;
  });

  Widget app({
    required TargetPlatform platform,
    required Widget body,
    bool tvDensity = false,
  }) {
    return MaterialApp(
      scrollBehavior: const ForjaScrollBehavior(),
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: ShellPaintScope(
          useTvFocus: tvDensity,
          scaleOnHover: !tvDensity,
          focusStyled: (_, {required focused}) => focused,
          usesTvDensity: tvDensity,
          child: body,
        ),
      ),
    );
  }

  ListView longList() => ListView(
        children: List.generate(
          40,
          (i) => SizedBox(height: 80, child: Text('row $i')),
        ),
      );

  testWidgets('Android TV density paints green RawScrollbar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      app(
        platform: TargetPlatform.android,
        tvDensity: true,
        body: longList(),
      ),
    );
    await tester.pump();

    expect(find.byType(RawScrollbar), findsOneWidget);
    final bar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
    expect(bar.thumbVisibility, isTrue);
    expect(bar.trackVisibility, isTrue);
    expect(bar.interactive, isFalse);
    expect(bar.thumbColor, ForjaScrollbarStyle.thumbColor);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android phone skips auto green scrollbar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    ShellTokens.nativeAndroidTvDetected = false;

    await tester.pumpWidget(
      app(
        platform: TargetPlatform.android,
        tvDensity: false,
        body: longList(),
      ),
    );
    await tester.pump();

    expect(find.byType(RawScrollbar), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop still paints green RawScrollbar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      app(
        platform: TargetPlatform.macOS,
        body: longList(),
      ),
    );
    await tester.pump();

    expect(find.byType(RawScrollbar), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
