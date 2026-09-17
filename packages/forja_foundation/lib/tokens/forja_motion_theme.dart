import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Closed interaction / motion intents. Widgets pick a name — never raw scales.
enum ForjaMotionPreset {
  cardLift,
  chipLift,
  fillOnly,
  railIcon,
  none,
}

/// Named specialized loops (still theme-owned numbers; not free-form FX).
enum ForjaMotionLoop {
  kenBurns,
  playPulse,
  favoriteHeartbeat,
}

/// One resolvable motion profile (hover/focus lift + duration + curve id).
@immutable
class ForjaMotionSpec {
  const ForjaMotionSpec({
    required this.hoverScale,
    required this.focusScale,
    required this.durationMs,
    this.curve = 'easeOutCubic',
  });

  final double hoverScale;
  final double focusScale;
  final int durationMs;
  final String curve;

  Duration get duration =>
      durationMs <= 0 ? Duration.zero : Duration(milliseconds: durationMs);

  Curve get resolvedCurve => switch (curve) {
        'easeOut' => Curves.easeOut,
        'easeInOut' => Curves.easeInOut,
        'linear' => Curves.linear,
        'easeOutCubic' || _ => Curves.easeOutCubic,
      };

  ForjaMotionSpec copyWith({
    double? hoverScale,
    double? focusScale,
    int? durationMs,
    String? curve,
  }) =>
      ForjaMotionSpec(
        hoverScale: hoverScale ?? this.hoverScale,
        focusScale: focusScale ?? this.focusScale,
        durationMs: durationMs ?? this.durationMs,
        curve: curve ?? this.curve,
      );

  ForjaMotionSpec mergeMap(Map<String, Object?>? raw) {
    if (raw == null || raw.isEmpty) return this;
    return copyWith(
      hoverScale: _asDouble(raw['hoverScale']) ?? hoverScale,
      focusScale: _asDouble(raw['focusScale']) ?? focusScale,
      durationMs: _asInt(raw['durationMs']) ?? durationMs,
      curve: raw['curve']?.toString() ?? curve,
    );
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}

/// Ken Burns / backdrop pan-zoom tunables (pack-overridable).
@immutable
class ForjaKenBurnsMotionSpec {
  const ForjaKenBurnsMotionSpec({
    required this.minScale,
    required this.maxScale,
    required this.cycleSeconds,
  });

  final double minScale;
  final double maxScale;
  final int cycleSeconds;

  ForjaKenBurnsMotionSpec mergeMap(Map<String, Object?>? raw) {
    if (raw == null || raw.isEmpty) return this;
    return ForjaKenBurnsMotionSpec(
      minScale: ForjaMotionSpec._asDouble(raw['minScale']) ?? minScale,
      maxScale: ForjaMotionSpec._asDouble(raw['maxScale']) ?? maxScale,
      cycleSeconds: ForjaMotionSpec._asInt(raw['cycleSeconds']) ?? cycleSeconds,
    );
  }
}

/// Pulse / heartbeat loop tunables.
@immutable
class ForjaPulseMotionSpec {
  const ForjaPulseMotionSpec({
    required this.peakScale,
    required this.midScale,
    required this.durationMs,
  });

  final double peakScale;
  final double midScale;
  final int durationMs;

  Duration get duration => Duration(milliseconds: durationMs);

  ForjaPulseMotionSpec mergeMap(Map<String, Object?>? raw) {
    if (raw == null || raw.isEmpty) return this;
    return ForjaPulseMotionSpec(
      peakScale: ForjaMotionSpec._asDouble(raw['peakScale']) ?? peakScale,
      midScale: ForjaMotionSpec._asDouble(raw['midScale']) ?? midScale,
      durationMs: ForjaMotionSpec._asInt(raw['durationMs']) ?? durationMs,
    );
  }
}

/// All motion numbers for the design system. Defaults live **only** here.
@immutable
class ForjaMotionTheme {
  const ForjaMotionTheme({
    required this.cardLift,
    required this.chipLift,
    required this.fillOnly,
    required this.railIcon,
    required this.none,
    required this.playButtonLift,
    required this.playPulse,
    required this.favoriteHeartbeat,
    required this.kenBurns,
    required this.shelfExpand,
    required this.shelfRevealDelayMs,
    required this.heroPillHover,
    required this.heroPillExpand,
    required this.heroPillLabel,
    required this.filterChrome,
    required this.filterPanel,
    required this.scrollSnap,
    required this.pageFade,
  });

  final ForjaMotionSpec cardLift;
  final ForjaMotionSpec chipLift;
  final ForjaMotionSpec fillOnly;
  final ForjaMotionSpec railIcon;
  final ForjaMotionSpec none;

  /// Play control lift (chip-sized; separate from [playPulse] loop).
  final ForjaMotionSpec playButtonLift;
  final ForjaPulseMotionSpec playPulse;
  final ForjaPulseMotionSpec favoriteHeartbeat;
  final ForjaKenBurnsMotionSpec kenBurns;

  /// WidgetShelf tab expand / reveal choreography.
  final ForjaMotionSpec shelfExpand;
  final int shelfRevealDelayMs;

  /// Hero pill glass hover + expand morphs.
  final ForjaMotionSpec heroPillHover;
  final ForjaMotionSpec heroPillExpand;
  final ForjaMotionSpec heroPillLabel;

  /// Search filter lens / panel chrome.
  final ForjaMotionSpec filterChrome;
  final ForjaMotionSpec filterPanel;

  /// Horizontal scroller snap / panel height factor.
  final ForjaMotionSpec scrollSnap;

  /// Hero page / logo fade transitions.
  final ForjaMotionSpec pageFade;

  /// Canonical defaults — the only place foundation defines motion numbers.
  ///
  /// [railIcon] duration matches [ShellTokens.navRailIconScaleAnimation] (520ms).
  static const ForjaMotionTheme defaults = ForjaMotionTheme(
    cardLift: ForjaMotionSpec(
      hoverScale: 1.05,
      focusScale: 1.05,
      durationMs: 180,
    ),
    chipLift: ForjaMotionSpec(
      hoverScale: 1.04,
      focusScale: 1.04,
      durationMs: 120,
    ),
    fillOnly: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 120,
    ),
    railIcon: ForjaMotionSpec(
      hoverScale: ShellTokens.navRailIconHoverScale,
      focusScale: ShellTokens.navRailIconHoverScale,
      durationMs: 520,
    ),
    none: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 0,
    ),
    playButtonLift: ForjaMotionSpec(
      hoverScale: 1.1,
      focusScale: 1.1,
      durationMs: 200,
    ),
    playPulse: ForjaPulseMotionSpec(
      peakScale: 1.12,
      midScale: 1.07,
      durationMs: 2600,
    ),
    favoriteHeartbeat: ForjaPulseMotionSpec(
      peakScale: 1.18,
      midScale: 1.0,
      durationMs: 120,
    ),
    kenBurns: ForjaKenBurnsMotionSpec(
      minScale: 1.0,
      maxScale: 1.12,
      cycleSeconds: 25,
    ),
    shelfExpand: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 200,
    ),
    shelfRevealDelayMs: 90,
    heroPillHover: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 140,
    ),
    heroPillExpand: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 420,
    ),
    heroPillLabel: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 480,
    ),
    filterChrome: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 160,
    ),
    filterPanel: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 280,
    ),
    scrollSnap: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 220,
    ),
    pageFade: ForjaMotionSpec(
      hoverScale: 1.0,
      focusScale: 1.0,
      durationMs: 450,
    ),
  );

  static ForjaMotionTheme of(BuildContext context) =>
      ForjaMotionScope.maybeOf(context)?.theme ?? defaults;

  static ForjaMotionTheme? maybeOf(BuildContext context) =>
      ForjaMotionScope.maybeOf(context)?.theme;

  ForjaMotionSpec resolve(ForjaMotionPreset preset) => switch (preset) {
        ForjaMotionPreset.cardLift => cardLift,
        ForjaMotionPreset.chipLift => chipLift,
        ForjaMotionPreset.fillOnly => fillOnly,
        ForjaMotionPreset.railIcon => railIcon,
        ForjaMotionPreset.none => none,
      };

  /// Parse preset name from pack JSON (`cardLift`, `chip_lift`, …).
  static ForjaMotionPreset? presetFromName(String? raw) {
    if (raw == null) return null;
    final n = raw.trim();
    if (n.isEmpty) return null;
    final key = n.replaceAll('-', '_').toLowerCase();
    return switch (key) {
      'cardlift' || 'card_lift' => ForjaMotionPreset.cardLift,
      'chiplift' || 'chip_lift' => ForjaMotionPreset.chipLift,
      'fillonly' || 'fill_only' => ForjaMotionPreset.fillOnly,
      'railicon' || 'rail_icon' => ForjaMotionPreset.railIcon,
      'none' => ForjaMotionPreset.none,
      _ => null,
    };
  }

  /// Merge pack `motion: { cardLift: { hoverScale: … }, … }`. Unknown keys ignored.
  ForjaMotionTheme merge(Map<String, Object?>? overlay) {
    if (overlay == null || overlay.isEmpty) return this;
    Map<String, Object?>? entry(String a, String b) {
      final v = overlay[a] ?? overlay[b];
      if (v is Map) return Map<String, Object?>.from(v);
      return null;
    }

    return ForjaMotionTheme(
      cardLift: cardLift.mergeMap(entry('cardLift', 'card_lift')),
      chipLift: chipLift.mergeMap(entry('chipLift', 'chip_lift')),
      fillOnly: fillOnly.mergeMap(entry('fillOnly', 'fill_only')),
      railIcon: railIcon.mergeMap(entry('railIcon', 'rail_icon')),
      none: none.mergeMap(entry('none', 'none')),
      playButtonLift:
          playButtonLift.mergeMap(entry('playButtonLift', 'play_button_lift')),
      playPulse: playPulse.mergeMap(entry('playPulse', 'play_pulse')),
      favoriteHeartbeat: favoriteHeartbeat
          .mergeMap(entry('favoriteHeartbeat', 'favorite_heartbeat')),
      kenBurns: kenBurns.mergeMap(entry('kenBurns', 'ken_burns')),
      shelfExpand: shelfExpand.mergeMap(entry('shelfExpand', 'shelf_expand')),
      shelfRevealDelayMs:
          ForjaMotionSpec._asInt(overlay['shelfRevealDelayMs']) ??
              ForjaMotionSpec._asInt(overlay['shelf_reveal_delay_ms']) ??
              shelfRevealDelayMs,
      heroPillHover:
          heroPillHover.mergeMap(entry('heroPillHover', 'hero_pill_hover')),
      heroPillExpand:
          heroPillExpand.mergeMap(entry('heroPillExpand', 'hero_pill_expand')),
      heroPillLabel:
          heroPillLabel.mergeMap(entry('heroPillLabel', 'hero_pill_label')),
      filterChrome:
          filterChrome.mergeMap(entry('filterChrome', 'filter_chrome')),
      filterPanel: filterPanel.mergeMap(entry('filterPanel', 'filter_panel')),
      scrollSnap: scrollSnap.mergeMap(entry('scrollSnap', 'scroll_snap')),
      pageFade: pageFade.mergeMap(entry('pageFade', 'page_fade')),
    );
  }

  /// Per-node: optional preset rename + numeric fields applied to that preset.
  ForjaMotionTheme mergeNodeProps(Map<String, dynamic> props) {
    final motionRaw = props['motion'];
    if (motionRaw is Map) {
      return merge(Map<String, Object?>.from(motionRaw));
    }
    final preset = presetFromName(motionRaw?.toString());
    final hasNums = props.containsKey('hoverScale') ||
        props.containsKey('focusScale') ||
        props.containsKey('durationMs') ||
        props.containsKey('curve');
    if (preset == null && !hasNums) return this;
    final target = preset ?? ForjaMotionPreset.chipLift;
    final patch = <String, Object?>{
      if (props['hoverScale'] != null) 'hoverScale': props['hoverScale'],
      if (props['focusScale'] != null) 'focusScale': props['focusScale'],
      if (props['durationMs'] != null) 'durationMs': props['durationMs'],
      if (props['curve'] != null) 'curve': props['curve'],
    };
    final key = switch (target) {
      ForjaMotionPreset.cardLift => 'cardLift',
      ForjaMotionPreset.chipLift => 'chipLift',
      ForjaMotionPreset.fillOnly => 'fillOnly',
      ForjaMotionPreset.railIcon => 'railIcon',
      ForjaMotionPreset.none => 'none',
    };
    return merge({key: patch});
  }

  /// Scale when [active] (typically [ShellPaintScope.interactiveActive]).
  ///
  /// Leanback (`scaleOnHover: false`) still applies [ForjaMotionSpec.focusScale]
  /// when active via focus.
  double scaleForActive(BuildContext context, ForjaMotionPreset preset, bool active) {
    if (!active) return 1.0;
    final spec = resolve(preset);
    if (ShellPaintScope.scaleOnHoverOf(context)) return spec.hoverScale;
    return spec.focusScale;
  }

  /// Scale to apply for [preset] given hover/focus + leanback policy.
  double effectiveScale(
    BuildContext context,
    ForjaMotionPreset preset, {
    required bool hovered,
    required bool focused,
  }) {
    final active = ShellPaintScope.interactiveActive(
      context,
      hovered: hovered,
      focused: focused,
    );
    return scaleForActive(context, preset, active);
  }
}

/// Subtree motion overrides (pack layout `motion{}` or per-node props).
class ForjaMotionScope extends InheritedWidget {
  const ForjaMotionScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final ForjaMotionTheme theme;

  static ForjaMotionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ForjaMotionScope>();

  /// Wrap [child] when [raw] is a non-empty motion map (pack-wide or node).
  static Widget wrapOverlay({
    required BuildContext context,
    required Object? raw,
    required Widget child,
  }) {
    if (raw is! Map || raw.isEmpty) return child;
    final base = ForjaMotionTheme.of(context);
    return ForjaMotionScope(
      theme: base.merge(Map<String, Object?>.from(raw)),
      child: child,
    );
  }

  /// Wrap when kit [props] carry `motion` map/name or numeric overrides.
  static Widget wrapProps({
    required BuildContext context,
    required Map<String, dynamic> props,
    required Widget child,
  }) {
    final motionRaw = props['motion'];
    final hasNums = props.containsKey('hoverScale') ||
        props.containsKey('focusScale') ||
        props.containsKey('durationMs') ||
        props.containsKey('curve');
    if (motionRaw == null && !hasNums) return child;
    return ForjaMotionScope(
      theme: ForjaMotionTheme.of(context).mergeNodeProps(props),
      child: child,
    );
  }

  @override
  bool updateShouldNotify(ForjaMotionScope oldWidget) =>
      !identical(theme, oldWidget.theme);
}

/// [AnimatedScale] driven by [ForjaMotionTheme] — no literals at call sites.
class ForjaMotionScale extends StatelessWidget {
  const ForjaMotionScale({
    super.key,
    required this.preset,
    required this.active,
    required this.child,
    this.alignment = Alignment.center,
    this.filterQuality,
  });

  final ForjaMotionPreset preset;

  /// Usually [ShellPaintScope.interactiveActive] (hover and/or focus).
  final bool active;
  final Widget child;
  final Alignment alignment;
  final FilterQuality? filterQuality;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaMotionTheme.of(context);
    final spec = theme.resolve(preset);
    final scale = theme.scaleForActive(context, preset, active);

    return AnimatedScale(
      scale: scale <= 0 ? 1.0 : scale,
      duration: spec.duration,
      curve: spec.resolvedCurve,
      alignment: alignment,
      filterQuality: filterQuality,
      child: child,
    );
  }
}
