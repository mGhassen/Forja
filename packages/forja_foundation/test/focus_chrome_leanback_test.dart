import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/focus_chrome_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/shell_mood_circle.dart';
import 'package:forja_foundation/widgets/chrome/focus_chrome.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Leanback = TV focus without hover scale; desktop hybrid = both.
Widget _wrap({required bool leanback, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellPaintScope(
        useTvFocus: true,
        scaleOnHover: !leanback,
        usesTvDensity: leanback,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

bool _isLeanbackRing(Decoration? d) {
  if (d is! BoxDecoration) return false;
  final b = d.border;
  if (b is! Border) return false;
  return b.top.color == FocusChromeTokens.ringColor &&
      b.top.width == FocusChromeTokens.ringWidth;
}

bool _hasGlow(Decoration? d) {
  if (d is! BoxDecoration) return false;
  final shadows = d.boxShadow;
  if (shadows == null) return false;
  return shadows.any(
    (s) =>
        s.blurRadius == FocusChromeTokens.glowBlur &&
        s.color == FocusChromeTokens.glowColor(),
  );
}

/// Focus the fallback InkWell that [ShellPaintScope.focusableTap] mounts when
/// no host builder is registered.
Future<void> _focusWithin(WidgetTester tester, Finder within) async {
  final text = find.descendant(of: within, matching: find.byType(Text)).first;
  final el = tester.element(text);
  FocusScope.of(el).requestFocus(Focus.of(el));
  // Focus applies in a microtask; the widget's setState lands a frame later.
  await tester.pump();
  await tester.pump();
}

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
  return gesture;
}

Decoration? _chipDecoration(WidgetTester tester) {
  final box = find.descendant(
    of: find.byType(ForjaShellChip),
    matching: find.byType(AnimatedContainer),
  );
  return tester.widget<AnimatedContainer>(box.first).decoration;
}

Decoration? _moodCircleDecoration(WidgetTester tester) {
  final boxes = tester
      .widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(ShellMoodCircleItem),
          matching: find.byType(AnimatedContainer),
        ),
      )
      .map((w) => w.decoration)
      .whereType<BoxDecoration>();
  return boxes.firstWhere((d) => d.shape == BoxShape.circle);
}

void main() {
  test('focus chrome tokens: one signature, per-family lift', () {
    expect(FocusChromeTokens.ringColor, ForjaShellColors.brandGreen);
    expect(FocusChromeTokens.cardScale, ShellTokens.focusActiveScale);
    expect(FocusChromeTokens.cardScale, 1.08);
    expect(
      FocusChromeTokens.chipScale,
      ForjaMotionTheme.defaults.chipLift.focusScale,
    );
    expect(FocusChromeTokens.rowScale, 1.0);
    expect(FocusChromeTokens.leanbackTween, Duration.zero);

    final ring = FocusChromeTokens.ring(borderRadius: BorderRadius.circular(8));
    expect(_isLeanbackRing(ring), isTrue);
    expect(_hasGlow(ring), isTrue);
    expect(ring.borderRadius, BorderRadius.circular(8));

    final circle = FocusChromeTokens.ring(shape: BoxShape.circle);
    expect(circle.shape, BoxShape.circle);
    expect(circle.borderRadius, isNull);

    final flat = FocusChromeTokens.ring(
      borderRadius: BorderRadius.circular(4),
      withGlow: false,
    );
    expect(flat.boxShadow, isNull);
  });

  testWidgets('FocusChromeRing: paint only — idle paints nothing, active '
      'paints the ring without changing layout', (tester) async {
    Widget build(bool active) => _wrap(
      leanback: true,
      child: FocusChromeRing(
        active: active,
        borderRadius: BorderRadius.circular(FocusChromeTokens.textPillRadius),
        inset: const EdgeInsets.symmetric(
          horizontal: FocusChromeTokens.textPillInsetH,
          vertical: FocusChromeTokens.textPillInsetV,
        ),
        child: const SizedBox(width: 100, height: 40),
      ),
    );

    await tester.pumpWidget(build(false));
    // Idle: the ring slot is mounted but paints nothing.
    final idle = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    expect(idle.decoration, const BoxDecoration());
    expect(tester.getSize(find.byType(FocusChromeRing)), const Size(100, 40));

    await tester.pumpWidget(build(true));
    expect(tester.getSize(find.byType(FocusChromeRing)), const Size(100, 40));
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    expect(_isLeanbackRing(box.decoration), isTrue);
    expect(_hasGlow(box.decoration), isTrue);
    expect(
      (box.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(FocusChromeTokens.textPillRadius),
      reason: 'ring radius follows the control',
    );
    // Pill sits outside the child box by the inset.
    final pill = tester.getRect(find.byType(DecoratedBox));
    final child = tester.getRect(find.byType(FocusChromeRing));
    expect(pill.left, child.left - FocusChromeTokens.textPillInsetH);
    expect(pill.top, child.top - FocusChromeTokens.textPillInsetV);
  });

  testWidgets('FocusChromeRing: child State survives focus enter / leave', (
    tester,
  ) async {
    Widget build(bool active) => _wrap(
      leanback: true,
      child: FocusChromeRing(
        active: active,
        behind: true,
        borderRadius: BorderRadius.circular(8),
        inset: const EdgeInsets.all(4),
        fill: FocusChromeTokens.backplateFill(),
        child: const _Counter(),
      ),
    );

    await tester.pumpWidget(build(false));
    final idleState = tester.state<_CounterState>(find.byType(_Counter));
    idleState.bump();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(build(true));
    expect(tester.state<_CounterState>(find.byType(_Counter)), same(idleState));
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(build(false));
    expect(tester.state<_CounterState>(find.byType(_Counter)), same(idleState));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('chip: leanback focus paints ring + glow + backplate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        leanback: true,
        child: ForjaShellChip(label: 'Action', onTap: () {}),
      ),
    );
    expect(_isLeanbackRing(_chipDecoration(tester)), isFalse);

    await _focusWithin(tester, find.byType(ForjaShellChip));

    final d = _chipDecoration(tester);
    expect(_isLeanbackRing(d), isTrue);
    expect(_hasGlow(d), isTrue);
    expect((d as BoxDecoration).color, FocusChromeTokens.backplateFill());
  });

  testWidgets('chip: desktop hover and keyboard focus keep the accent pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        leanback: false,
        child: ForjaShellChip(label: 'Action', onTap: () {}),
      ),
    );

    await _hover(tester, find.byType(ForjaShellChip));
    var d = _chipDecoration(tester) as BoxDecoration;
    expect(_isLeanbackRing(d), isFalse);
    expect(_hasGlow(d), isFalse);
    expect(
      (d.border as Border).top.color,
      ForjaShellColors.cinematic.borderSubtle,
    );

    await _focusWithin(tester, find.byType(ForjaShellChip));
    d = _chipDecoration(tester) as BoxDecoration;
    // Desktop keyboard focus: thin accent pill, no ring width, no glow.
    expect((d.border as Border).top.color, ForjaShellColors.brandGreen);
    expect((d.border as Border).top.width, 1.5);
    expect(_hasGlow(d), isFalse);
  });

  testWidgets('mood circle: leanback focus paints ring + glow on the circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        leanback: true,
        child: ShellMoodCircleItem(
          layout: MoodCircleLayout.tvScrollable,
          label: 'Soccer',
          icon: Icons.sports_soccer,
          accent: const Color(0xFF22C55E),
          selected: false,
          onTap: () {},
        ),
      ),
    );
    expect(_isLeanbackRing(_moodCircleDecoration(tester)), isFalse);

    await _focusWithin(tester, find.byType(ShellMoodCircleItem));

    final d = _moodCircleDecoration(tester) as BoxDecoration;
    expect(d.shape, BoxShape.circle);
    expect(_isLeanbackRing(d), isTrue);
    expect(_hasGlow(d), isTrue);
    // Snaps on leanback — no 120 ms chip tween.
    final circle = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byType(ShellMoodCircleItem),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .firstWhere((w) => identical(w.decoration, d));
    expect(circle.duration, FocusChromeTokens.leanbackTween);
    // Label still turns accent on focus.
    final label = tester.widget<Text>(find.text('Soccer'));
    expect(label.style?.color, ForjaShellColors.brandGreen);
  });

  testWidgets('mood circle: desktop hover keeps its own accent glow', (
    tester,
  ) async {
    const accent = Color(0xFF22C55E);
    await tester.pumpWidget(
      _wrap(
        leanback: false,
        child: ShellMoodCircleItem(
          layout: MoodCircleLayout.desktop,
          label: 'Soccer',
          icon: Icons.sports_soccer,
          accent: accent,
          selected: false,
          onTap: () {},
        ),
      ),
    );

    await _hover(tester, find.byType(ShellMoodCircleItem));

    final d = _moodCircleDecoration(tester) as BoxDecoration;
    expect(_isLeanbackRing(d), isFalse);
    expect((d.border as Border).top.color, accent.withValues(alpha: 0.95));
    expect(d.boxShadow, isNotNull);
    expect(_hasGlow(d), isFalse);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  void bump() => setState(() => count++);

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 40, height: 40, child: Text('$count'));
}
