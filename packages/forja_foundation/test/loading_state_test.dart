import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/components/spinner.dart';
import 'package:forja_foundation/tokens/loading_state_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/loading_state.dart';

Widget _host(Widget child, {required bool tv}) {
  return MaterialApp(
    home: Scaffold(
      body: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        focusStyled: (_, {required focused}) => focused,
        usesTvDensity: tv,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('paints a spinner and the given title', (tester) async {
    await tester.pumpWidget(
      _host(const ForjaLoadingState(title: 'Synthetic Title'), tv: false),
    );
    await tester.pump();

    expect(find.byType(Spinner), findsOneWidget);
    expect(find.text('Synthetic Title'), findsOneWidget);
    expect(find.text(ForjaLoadingState.defaultTitle), findsNothing);
  });

  testWidgets('blank title falls back to the default copy', (tester) async {
    await tester.pumpWidget(
      _host(const ForjaLoadingState(title: '   '), tv: false),
    );
    await tester.pump();

    expect(find.text(ForjaLoadingState.defaultTitle), findsOneWidget);
  });

  testWidgets('TV density uses the hand-tuned spinner size', (tester) async {
    await tester.pumpWidget(
      _host(const ForjaLoadingState(title: 'x'), tv: true),
    );
    await tester.pump();

    final spinner = tester.widget<Spinner>(find.byType(Spinner));
    expect(spinner.dimension, LoadingStateTokens.spinnerTv);
    final size = tester.getSize(find.byType(Spinner));
    expect(size.width, LoadingStateTokens.spinnerTv);
    expect(size.height, LoadingStateTokens.spinnerTv);
  });

  testWidgets('desktop density uses the desktop spinner size', (tester) async {
    await tester.pumpWidget(
      _host(const ForjaLoadingState(title: 'x'), tv: false),
    );
    await tester.pump();

    final size = tester.getSize(find.byType(Spinner));
    expect(size.width, LoadingStateTokens.spinner);
  });

  testWidgets('detail, hint and actions render under the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ForjaLoadingState(
          title: 'Checking sources',
          detail: 'Server A · English',
          hint: 'Press Back to cancel',
          actions: Text('actions-slot'),
        ),
        tv: true,
      ),
    );
    await tester.pump();

    expect(find.text('Checking sources'), findsOneWidget);
    expect(find.text('Server A · English'), findsOneWidget);
    expect(find.text('Press Back to cancel'), findsOneWidget);
    expect(find.text('actions-slot'), findsOneWidget);

    final titleY = tester.getCenter(find.text('Checking sources')).dy;
    final detailY = tester.getCenter(find.text('Server A · English')).dy;
    final hintY = tester.getCenter(find.text('Press Back to cancel')).dy;
    final actionsY = tester.getCenter(find.text('actions-slot')).dy;
    expect(titleY, lessThan(detailY));
    expect(detailY, lessThan(hintY));
    expect(hintY, lessThan(actionsY));
  });

  testWidgets('icon replaces the spinner for terminal states', (tester) async {
    await tester.pumpWidget(
      _host(
        const ForjaLoadingState(
          title: 'Failed to stream',
          icon: Icons.error_outline_rounded,
        ),
        tv: true,
      ),
    );
    await tester.pump();

    expect(find.byType(Spinner), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('is centered in its parent', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 800,
          height: 500,
          child: ForjaLoadingState(title: 'Centered'),
        ),
        tv: true,
      ),
    );
    await tester.pump();

    final box = tester.getRect(find.byType(SizedBox).first);
    final center = tester.getCenter(find.text('Centered'));
    expect(center.dx, closeTo(box.center.dx, 1));
  });
}
