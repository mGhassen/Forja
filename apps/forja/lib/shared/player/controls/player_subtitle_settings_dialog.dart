import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_menu_return_focus.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_seek_scrub_cancel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';

class PlayerSubtitleSettingsValues {
  const PlayerSubtitleSettingsValues({
    required this.size,
    required this.delay,
    required this.color,
    required this.bgOpacity,
    required this.bottomPadding,
    required this.bold,
    required this.font,
  });

  final double size;
  final double delay;
  final Color color;
  final double bgOpacity;
  final double bottomPadding;
  final bool bold;
  final String font;
}

/// Subtitle appearance dialog - touch + TV D-pad (sliders, chips, toggles).
///
/// Uses [OverlayEntry] (not [showDialog]) so remote Back dismisses via
/// [dismissAnyPlayerChromeOverlay] without racing the player route pop.
class PlayerSubtitleSettingsDialog {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static bool dismissIfShowing() {
    if (_entry == null) return false;
    dismiss();
    return true;
  }

  static void dismiss() {
    final wasShowing = _entry != null;
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
    if (wasShowing) playerMenuRestoreReturnFocus();
  }

  static Future<void> show(
    BuildContext context, {
    required PlayerSubtitleSettingsValues initial,
    required void Function(PlayerSubtitleSettingsValues values) onChanged,
    Player? player,
  }) {
    playerMenuCaptureReturnFocus(context);
    dismiss();
    playerChromeCancelSeekScrubs();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    void close() => dismiss();

    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (ctx, _) => _SubtitleSettingsOverlay(
          initial: initial,
          onChanged: onChanged,
          player: player,
          onClose: close,
        ),
      ),
    );
    overlay.insert(_entry!);
    return _completer!.future;
  }

  static void _applyDelay(Player? player, double delay) {
    final platform = player?.platform;
    if (platform is! NativePlayer || platform.disposed) return;
    // Runtime prop — skip init wait (same pattern as sub-visibility toggles).
    unawaited(
      platform.setProperty(
        'sub-delay',
        delay.toString(),
        waitForInitialization: false,
      ),
    );
  }

  static const _fonts = [
    'Default',
    'Poppins',
    'Roboto',
    'Roboto Mono',
    'Montserrat',
    'Open Sans',
    'Lato',
  ];

  static const _colorOptions = <String, Color>{
    'White': Colors.white,
    'Yellow': Color(0xFFFFEB3B),
    'Cyan': Color(0xFF00E5FF),
    'Green': Color(0xFF69F0AE),
    'Orange': Color(0xFFFFAB40),
    'Pink': Color(0xFFFF80AB),
  };
}

class _SubtitleSettingsOverlay extends StatefulWidget {
  const _SubtitleSettingsOverlay({
    required this.initial,
    required this.onChanged,
    required this.onClose,
    this.player,
  });

  final PlayerSubtitleSettingsValues initial;
  final void Function(PlayerSubtitleSettingsValues values) onChanged;
  final VoidCallback onClose;
  final Player? player;

  @override
  State<_SubtitleSettingsOverlay> createState() =>
      _SubtitleSettingsOverlayState();
}

class _SubtitleSettingsOverlayState extends State<_SubtitleSettingsOverlay> {
  late PlayerSubtitleSettingsValues _values = widget.initial;

  void _apply(void Function() mutate) {
    setState(mutate);
    widget.onChanged(_values);
  }

  void _close() {
    SettingsService().setSubSize(_values.size);
    SettingsService().setSubBgOpacity(_values.bgOpacity);
    SettingsService().setSubBottomPadding(_values.bottomPadding);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    final panel = Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              (MediaQuery.sizeOf(context).width * 0.9).clamp(280.0, 420.0),
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PlayerPopupTokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Subtitle Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ForjaCloseButton.compact(onTap: _close),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SubSlider(
                        label: 'Size',
                        value: _values.size,
                        min: 10,
                        max: 80,
                        trailing: '${_values.size.toInt()}',
                        tvFocus: tv,
                        autofocus: tv,
                        onChanged: (v) => _apply(() => _values =
                            PlayerSubtitleSettingsValues(
                              size: v,
                              delay: _values.delay,
                              color: _values.color,
                              bgOpacity: _values.bgOpacity,
                              bottomPadding: _values.bottomPadding,
                              bold: _values.bold,
                              font: _values.font,
                            )),
                      ),
                      const SizedBox(height: 8),
                      _DelayRow(
                        delay: _values.delay,
                        tvFocus: tv,
                        onDelta: (delta) {
                          final d = double.parse(
                            (_values.delay + delta).toStringAsFixed(1),
                          );
                          _apply(() => _values = PlayerSubtitleSettingsValues(
                                size: _values.size,
                                delay: d,
                                color: _values.color,
                                bgOpacity: _values.bgOpacity,
                                bottomPadding: _values.bottomPadding,
                                bold: _values.bold,
                                font: _values.font,
                              ));
                          PlayerSubtitleSettingsDialog._applyDelay(
                            widget.player,
                            d,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Text Color',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: PlayerSubtitleSettingsDialog._colorOptions
                            .entries
                            .map((e) {
                          final selected = _values.color.toARGB32() ==
                              e.value.toARGB32();
                          return _SubColorSwatch(
                            key: ValueKey('sub-color-${e.key}'),
                            color: e.value,
                            selected: selected,
                            tvFocus: tv,
                            onSelect: () {
                              _apply(() {
                                _values = PlayerSubtitleSettingsValues(
                                  size: _values.size,
                                  delay: _values.delay,
                                  color: e.value,
                                  bgOpacity: _values.bgOpacity,
                                  bottomPadding: _values.bottomPadding,
                                  bold: _values.bold,
                                  font: _values.font,
                                );
                                SettingsService()
                                    .setSubColor(e.value.toARGB32());
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      _SubSlider(
                        label: 'BG Opacity',
                        value: _values.bgOpacity,
                        min: 0,
                        max: 1,
                        trailing: '${(_values.bgOpacity * 100).toInt()}%',
                        tvFocus: tv,
                        onChanged: (v) => _apply(() => _values =
                            PlayerSubtitleSettingsValues(
                              size: _values.size,
                              delay: _values.delay,
                              color: _values.color,
                              bgOpacity: v,
                              bottomPadding: _values.bottomPadding,
                              bold: _values.bold,
                              font: _values.font,
                            )),
                      ),
                      const SizedBox(height: 8),
                      _SubSlider(
                        label: 'Position',
                        value: _values.bottomPadding,
                        min: 0,
                        max: 120,
                        trailing: '${_values.bottomPadding.toInt()}',
                        tvFocus: tv,
                        onChanged: (v) => _apply(() => _values =
                            PlayerSubtitleSettingsValues(
                              size: _values.size,
                              delay: _values.delay,
                              color: _values.color,
                              bgOpacity: _values.bgOpacity,
                              bottomPadding: v,
                              bold: _values.bold,
                              font: _values.font,
                            )),
                      ),
                      const SizedBox(height: 8),
                      _BoldRow(
                        bold: _values.bold,
                        tvFocus: tv,
                        onChanged: (v) {
                          _apply(() => _values = PlayerSubtitleSettingsValues(
                                size: _values.size,
                                delay: _values.delay,
                                color: _values.color,
                                bgOpacity: _values.bgOpacity,
                                bottomPadding: _values.bottomPadding,
                                bold: v,
                                font: _values.font,
                              ));
                          SettingsService().setSubBold(v);
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Font',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: PlayerSubtitleSettingsDialog._fonts.map((f) {
                          final selected = _values.font == f;
                          final chip = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? ForjaShellColors.brandGreen
                                      .withValues(alpha: 0.14)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? ForjaShellColors.brandGreen
                                    : Colors.white12,
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                color: selected
                                    ? ForjaShellColors.brandGreen
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                          if (!tv) {
                            return GestureDetector(
                              key: ValueKey('sub-font-$f'),
                              onTap: () {
                                _apply(() {
                                  _values = PlayerSubtitleSettingsValues(
                                    size: _values.size,
                                    delay: _values.delay,
                                    color: _values.color,
                                    bgOpacity: _values.bgOpacity,
                                    bottomPadding: _values.bottomPadding,
                                    bold: _values.bold,
                                    font: f,
                                  );
                                  SettingsService().setSubFont(f);
                                });
                              },
                              child: chip,
                            );
                          }
                          return KeyedSubtree(
                            key: ValueKey('sub-font-$f'),
                            child: shellFocusableTap(
                              context: context,
                              onTap: () {
                                _apply(() {
                                  _values = PlayerSubtitleSettingsValues(
                                    size: _values.size,
                                    delay: _values.delay,
                                    color: _values.color,
                                    bgOpacity: _values.bgOpacity,
                                    bottomPadding: _values.bottomPadding,
                                    bold: _values.bold,
                                    font: f,
                                  );
                                  SettingsService().setSubFont(f);
                                });
                              },
                              borderRadius: 8,
                              scaleOnFocus: 1.0,
                              showFocusBorder: true,
                              child: chip,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final body = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: panel,
          ),
        ),
      ],
    );

    if (!tv) return body;

    // Linear reading-order so color/font chips are reachable — spatial
    // focusInDirection skips the small Wrap circles between wide sliders.
    return TvOverlayScope(
      onDismiss: _close,
      linear: true,
      policy: ReadingOrderTraversalPolicy(),
      child: body,
    );
  }
}

class _SubSlider extends StatefulWidget {
  const _SubSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.trailing,
    required this.onChanged,
    required this.tvFocus,
    this.autofocus = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String trailing;
  final ValueChanged<double> onChanged;
  final bool tvFocus;
  final bool autofocus;

  @override
  State<_SubSlider> createState() => _SubSliderState();
}

class _SubSliderState extends State<_SubSlider> {
  bool _focused = false;

  void _nudge(double delta) {
    final step = (widget.max - widget.min) / 20;
    final next = (widget.value + delta * step)
        .clamp(widget.min, widget.max)
        .toDouble();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final slider = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            Text(
              widget.trailing,
              style: TextStyle(
                color: _focused
                    ? ForjaShellColors.brandGreen
                    : Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
        ExcludeFocus(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: _focused ? 4 : 3,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: _focused ? 8 : 7,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: _focused
                  ? ForjaShellColors.brandGreen
                  : const Color(0xFF7C3AED),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: _focused
                  ? ForjaShellColors.brandGreen
                  : const Color(0xFF7C3AED),
            ),
            child: Slider(
              // Prefs / platform defaults can sit outside the slider range.
              value: widget.value.clamp(widget.min, widget.max).toDouble(),
              min: widget.min,
              max: widget.max,
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ],
    );

    if (!widget.tvFocus) return slider;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _nudge(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _nudge(1);
          return KeyEventResult.handled;
        }
        // ↑/↓ leave the slider and walk other controls.
        return shellTvLinearMenuArrows(context: context, event: event);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: _focused
              ? Border.all(color: ForjaShellColors.brandGreen, width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: slider,
        ),
      ),
    );
  }
}

class _SubColorSwatch extends StatefulWidget {
  const _SubColorSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.tvFocus,
    required this.onSelect,
  });

  final Color color;
  final bool selected;
  final bool tvFocus;
  final VoidCallback onSelect;

  @override
  State<_SubColorSwatch> createState() => _SubColorSwatchState();
}

class _SubColorSwatchState extends State<_SubColorSwatch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ring = _focused
        ? ForjaShellColors.brandGreen
        : widget.selected
            ? ForjaShellColors.brandGreen
            : Colors.white24;
    final ringWidth = (_focused || widget.selected) ? 3.0 : 1.0;
    final swatch = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: ringWidth),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: ForjaShellColors.brandGreen.withValues(alpha: 0.65),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: widget.selected
          ? Icon(
              Icons.check,
              size: 16,
              color: ForjaShellColors.brandGreen,
            )
          : null,
    );
    if (!widget.tvFocus) {
      return GestureDetector(onTap: widget.onSelect, child: swatch);
    }
    // Custom circle ring — flat FocusableControl border is a faint rounded
    // rect that disappears on white/yellow swatches.
    return shellFocusableTap(
      context: context,
      onTap: widget.onSelect,
      borderRadius: 17,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      onFocusChange: (f) => setState(() => _focused = f),
      child: swatch,
    );
  }
}

class _DelayRow extends StatelessWidget {
  const _DelayRow({
    required this.delay,
    required this.onDelta,
    required this.tvFocus,
  });

  final double delay;
  final ValueChanged<double> onDelta;
  final bool tvFocus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Delay',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const Spacer(),
        _DelayBumpButton(
          icon: Icons.remove,
          tvFocus: tvFocus,
          onStep: (steps) => onDelta(-0.1 * steps),
        ),
        SizedBox(
          width: 54,
          child: Text(
            '${delay.toStringAsFixed(1)}s',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _DelayBumpButton(
          icon: Icons.add,
          tvFocus: tvFocus,
          onStep: (steps) => onDelta(0.1 * steps),
        ),
      ],
    );
  }
}

/// TV: OK tap = one 0.1s step; hold OK (KeyRepeat) accelerates.
class _DelayBumpButton extends StatefulWidget {
  const _DelayBumpButton({
    required this.icon,
    required this.tvFocus,
    required this.onStep,
  });

  final IconData icon;
  final bool tvFocus;
  final ValueChanged<int> onStep;

  @override
  State<_DelayBumpButton> createState() => _DelayBumpButtonState();
}

class _DelayBumpButtonState extends State<_DelayBumpButton> {
  bool _focused = false;
  DateTime? _holdStarted;
  LogicalKeyboardKey? _holdKey;

  void _resetHold() {
    _holdStarted = null;
    _holdKey = null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!shellTvIsActivateLogicalKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) {
      _resetHold();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      _holdStarted = DateTime.now();
      _holdKey = event.logicalKey;
      widget.onStep(1);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent &&
        _holdKey == event.logicalKey &&
        _holdStarted != null) {
      final stride = ShellTvHoldAccel.stepForHoldMs(
        DateTime.now().difference(_holdStarted!).inMilliseconds,
      );
      widget.onStep(stride);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Desktop hybrid shares useFocusableMoodChips with TV, but mouse clicks on
    // FocusableControl race ensureVisible-on-focus and cancel the tap. Use
    // IconButton whenever we have a pointer (same pattern as Bold / Switch).
    final leanback = widget.tvFocus &&
        !(ShellScope.maybeOf(context)?.inputPolicy.scaleOnHover ?? true);
    if (!leanback) {
      return IconButton(
        icon: Icon(widget.icon, color: Colors.white70, size: 20),
        visualDensity: VisualDensity.compact,
        tooltip: widget.icon == Icons.add ? 'Increase delay' : 'Decrease delay',
        onPressed: () => widget.onStep(1),
      );
    }

    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: _focused ? ForjaShellColors.brandGreen : Colors.white24,
          width: _focused ? 2.5 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: ForjaShellColors.brandGreen.withValues(alpha: 0.55),
                  blurRadius: 0,
                  spreadRadius: 1.5,
                ),
              ]
            : null,
      ),
      child: Icon(widget.icon, color: Colors.white70, size: 20),
    );

    return shellFocusableTap(
      context: context,
      onTap: () => widget.onStep(1),
      borderRadius: 18,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      ensureVisibleMode: ShellTvEnsureVisibleMode.off,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (!f) _resetHold();
      },
      onKeyEvent: _onKey,
      child: btn,
    );
  }
}

class _BoldRow extends StatelessWidget {
  const _BoldRow({
    required this.bold,
    required this.onChanged,
    required this.tvFocus,
  });

  final bool bold;
  final ValueChanged<bool> onChanged;
  final bool tvFocus;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        const Text(
          'Bold',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const Spacer(),
        ForjaSwitch(
          value: bold,
          scale: ForjaSwitch.settingsScale,
          // Desktop hybrid: keep mouse toggle. Leanback: FocusableControl owns OK.
          onChanged: tvFocus &&
                  !(ShellScope.maybeOf(context)?.inputPolicy.scaleOnHover ??
                      true)
              ? null
              : onChanged,
        ),
      ],
    );
    if (!tvFocus) return row;
    return shellFocusableTap(
      context: context,
      onTap: () => onChanged(!bold),
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      child: row,
    );
  }
}
