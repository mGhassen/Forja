import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/catalog_dense_list.dart';

void main() {
  testWidgets(
    'dense list keep-visible scroll moves focus row without pinning to top',
    (tester) async {
      final scroll = ScrollController();
      const count = 40;
      const rowExtent = ShellTokens.denseListRowExtent;
      const stride = ShellTokens.denseListRowExtent + ShellTokens.denseListSeparator;
      const viewportH = 240.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: viewportH,
              child: CatalogDenseList(
                controller: scroll,
                itemCount: count,
                itemBuilder: (context, i) => Text('row-$i'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Land mid-list so both ↑ and ↓ need keep-visible, not a top pin.
      final mid = 12;
      scroll.jumpTo(
        (ShellTokens.denseListTopPad + mid * stride).clamp(
          0.0,
          scroll.position.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
      final offsetBefore = scroll.offset;

      // Next row is already fully on-screen → must not jump (hover moves down).
      CatalogDenseList.scrollIndexKeepVisible(
        scroll,
        index: mid + 1,
        rowExtent: rowExtent,
        stride: stride,
      );
      await tester.pump();
      expect(
        scroll.offset,
        offsetBefore,
        reason: 'fully visible next row must not pin-scroll the list',
      );

      // Force a clipped bottom row: jump so only the last visible index peeks.
      final lastVisible = ((offsetBefore + viewportH - ShellTokens.denseListTopPad) /
              stride)
          .floor()
          .clamp(0, count - 1);
      final beforeClip = scroll.offset;
      CatalogDenseList.scrollIndexKeepVisible(
        scroll,
        index: lastVisible + 2,
        rowExtent: rowExtent,
        stride: stride,
      );
      await tester.pump();
      expect(
        scroll.offset > beforeClip,
        isTrue,
        reason: 'clipped row below must nudge scroll down',
      );
      // Must not snap that index flush to the top (always-pin regress).
      final pinnedTop =
          ShellTokens.denseListTopPad + (lastVisible + 2) * stride;
      expect(
        (scroll.offset - pinnedTop).abs() > 1.0,
        isTrue,
        reason: 'keep-visible must not pin the focused row to content top',
      );

      scroll.dispose();
    },
  );
}
