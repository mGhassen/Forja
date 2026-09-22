import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:forja_foundation/widgets/guide/channel_search_overlay.dart';

void main() {
  testWidgets(
    'search result shows seeded health and probes after dwell on hover',
    (tester) async {
      final probed = <String>[];
      final guide = ChannelGuide(
        groups: const [GuideGroup(id: 'g', name: 'Sports')],
        channels: const [
          GuideChannel(id: 'c1', name: 'Alpha Sport', groupId: 'g'),
          GuideChannel(id: 'c2', name: 'Beta Sport', groupId: 'g'),
        ],
        initialChannelId: 'c1',
        initialGroupId: 'g',
        streamHealth: const {'c1': true},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelSearchOverlay(
              guide: guide,
              currentChannelId: 'c1',
              onChannelSelected: (_) {},
              onClose: () {},
              probeHealth: (ch) async {
                probed.add(ch.id);
                return ch.id == 'c2';
              },
            ),
          ),
        ),
      );

      // Type to surface results (GuideBrowseTextField wraps TextField).
      await tester.enterText(find.byType(TextField), 'Sport');
      await tester.pump();

      expect(find.text('Alpha Sport'), findsOneWidget);
      expect(probed, isEmpty);

      // Hover the second result — dwell matches guide (350ms).
      final beta = find.text('Beta Sport');
      expect(beta, findsOneWidget);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(beta));
      await tester.pump();
      expect(probed, isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(probed, ['c2']);
    },
  );
}
