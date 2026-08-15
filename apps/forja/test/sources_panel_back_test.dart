import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';

Widget _wrapTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    ShellTvFocusCoordinator.resetBackDebounceForTest();
  });

  tearDown(() {
    SourcesPanelTv.setFiltersDismiss(null);
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = false;
  });

  testWidgets('TV Back closes Sources without running the details pop', (
    tester,
  ) async {
    var panelClosed = 0;
    var detailsPopped = 0;
    ShellTvFocusCoordinator.setTransientOverlayDismiss(() {
      detailsPopped++;
      return true;
    });

    await tester.pumpWidget(
      _wrapTv(
        Builder(
          builder: (context) {
            return SourcesPanelTv.wrapBody(
              context: context,
              onClose: () => panelClosed++,
              child: const Text('sources-body'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('sources-body'), findsOneWidget);

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    expect(panelClosed, greaterThanOrEqualTo(1));
    expect(detailsPopped, 0);

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    expect(detailsPopped, 0);
  });

  testWidgets('TV Back closes Filters before Sources', (tester) async {
    var panelClosed = 0;
    var filtersClosed = 0;

    await tester.pumpWidget(
      _wrapTv(
        Builder(
          builder: (context) {
            return SourcesPanelTv.wrapBody(
              context: context,
              onClose: () => panelClosed++,
              child: const Text('sources-body'),
            );
          },
        ),
      ),
    );
    await tester.pump();

    SourcesPanelTv.setFiltersDismiss(() {
      filtersClosed++;
      SourcesPanelTv.setFiltersDismiss(null);
      return true;
    });

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    expect(filtersClosed, 1);
    expect(panelClosed, 0);

    await tester.pump(const Duration(milliseconds: 450));
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    expect(panelClosed, 1);
  });
}
