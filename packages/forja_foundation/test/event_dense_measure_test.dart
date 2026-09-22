import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

void main() {
  testWidgets('measure EventDenseTile unconstrained height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShellPaintScope(
          usesTvDensity: false,
          child: Scaffold(
            body: Center(
              child: EventDenseTile(
                title: 'New York Giants at Los Angeles Rams',
                meta: 'american-football · Live',
                airing: true,
                viewers: 9493,
                selected: false,
              ),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(EventDenseTile));
    // ignore: avoid_print
    print('desktop tile size=$size extent=${ShellTokens.denseListRowExtent}');

    await tester.pumpWidget(
      MaterialApp(
        home: ShellPaintScope(
          usesTvDensity: true,
          child: Scaffold(
            body: Center(
              child: EventDenseTile(
                title: 'New York Giants at Los Angeles Rams',
                meta: 'american-football · Live',
                airing: true,
                viewers: 9493,
                selected: false,
              ),
            ),
          ),
        ),
      ),
    );
    final tvSize = tester.getSize(find.byType(EventDenseTile));
    // ignore: avoid_print
    print('tv tile size=$tvSize extent=${ShellTokens.denseListRowExtentTv}');
  });
}
