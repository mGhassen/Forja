import 'dart:async';

import 'package:flutter/material.dart' hide Switch;
import 'package:flutter/services.dart';

import 'package:forja/shared/player/controls/menus/player_menu_return_focus.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/controls/chrome/player_seek_scrub_cancel.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/components/switch.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
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

  /// TV focus graph — one [TvKitRow] per settings line (not reading-order wrap).
  static const tvTabId = 'player-sub-settings';
  static const sizeRowId = 'sub-size';
  static const delayRowId = 'sub-delay';
  static const colorRowId = 'sub-color';
  static const bgRowId = 'sub-bg';
  static const posRowId = 'sub-pos';
  static const boldRowId = 'sub-bold';
  static const fontRowId = 'sub-font';
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
    final policy = ShellScope.inputPolicyOf(context);
    final tv = policy.useFocusableMoodChips;
    final leanback = policy.leanbackOnly;

    final panel = Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: leanback
              ? 280
              : (MediaQuery.sizeOf(context).width * 0.9).clamp(280.0, 420.0),
          maxHeight: leanback
              ? MediaQuery.sizeOf(context).height * 0.55
              : MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PlayerPopupTokens.shellRadius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PlayerPopupTokens.shellBg,
              borderRadius:
                  BorderRadius.circular(PlayerPopupTokens.shellRadius),
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
                      _PopupSettingsCloseButton(onTap: _close),
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
                      _tvRow(
                        tv: tv,
                        rowId: PlayerSubtitleSettingsDialog.sizeRowId,
                        sortOrder: 0,
                        itemCount: 1,
                        child: _SubSlider(
                          label: 'Size',
                          value: _values.size,
                          min: 10,
                          max: 80,
                          trailing: '${_values.size.toInt()}',
                          tvFocus: tv,
                          autofocus: tv,
                          tvRowId: PlayerSubtitleSettingsDialog.sizeRowId,
                          listIndex: 0,
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
                      ),
                      const SizedBox(height: 8),
                      _tvRow(
                        tv: tv,
                        rowId: PlayerSubtitleSettingsDialog.delayRowId,
                        sortOrder: 1,
                        itemCount: 2,
                        child: _DelayRow(
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
                      _tvRow(
                        tv: tv,
                        rowId: PlayerSubtitleSettingsDialog.colorRowId,
                        sortOrder: 2,
                        itemCount:
                            PlayerSubtitleSettingsDialog._colorOptions.length,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: () {
                            final entries = PlayerSubtitleSettingsDialog
                                ._colorOptions.entries
                                .toList();
                            return [
                              for (var i = 0; i < entries.length; i++)
                                _SubColorSwatch(
                                  key: ValueKey('sub-color-${entries[i].key}'),
                                  color: entries[i].value,
                                  selected: _values.color.toARGB32() ==
                                      entries[i].value.toARGB32(),
                                  tvFocus: tv,
                                  listIndex: i,
                                  onSelect: () {
                                    final c = entries[i].value;
                                    _apply(() {
                                      _values = PlayerSubtitleSettingsValues(
                                        size: _values.size,
                                        delay: _values.delay,
                                        color: c,
                                        bgOpacity: _values.bgOpacity,
                                        bottomPadding: _values.bottomPadding,
                                        bold: _values.bold,
                                        font: _values.font,
                                      );
                                      SettingsService()
                                          .setSubColor(c.toARGB32());
                                    });
                                  },
                                ),
                            ];
                          }(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _tvRow(
                        tv: tv,
                        rowId: PlayerSubtitleSettingsDialog.bgRowId,
                        sortOrder: 3,
                        itemCount: 1,
                        child: _SubSlider(
                          label: 'BG Opacity',
                          value: _values.bgOpacity,
                          min: 0,
                          max: 1,
                          trailing:
                              '${(_values.bgOpacity * 100).toInt()}%',
                          tvFocus: tv,
                          tvRowId: PlayerSubtitleSettingsDialog.bgRowId,
                          listIndex: 0,
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
                      ),
                      const SizedBox(height: 8),
                      _tvRow(
                        tv: tv,
                        rowId: PlayerSubtitleSettingsDialog.posRowId,
                        sortOrder: 4,
                        itemCount: 1,
                        child: _SubSlider(
                          label: 'Position',
                          value: _values.bottomPadding,
                          min: 0,
                          max: 120,
                          trailing: '${_values.bottomPadding.toInt()}',
                          tvFocus: tv,
                          tvRowId: PlayerSubtitleSettingsDialog.posRowId,
                          listIndex: 0,
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
                      ),
                      const SizedBox(height: 8),
                      _tvRow(
                        tv: tv,
                        rowId: PlayerSubtitleSettingsDialog.boldRowId,
                        sortOrder: 5,
                        itemCount: 1,
                        child: _BoldRow(
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
                      _tvRow(
                        tv: tv,
                        rowId: PlayerSubtitleSettingsDialog.fontRowId,
                        sortOrder: 6,
                        itemCount: PlayerSubtitleSettingsDialog._fonts.length,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0;
                                i < PlayerSubtitleSettingsDialog._fonts.length;
                                i++)
                              _buildFontChip(
                                context,
                                tv: tv,
                                font: PlayerSubtitleSettingsDialog._fonts[i],
                                index: i,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            child: ColoredBox(
              color: leanback
                  ? const Color(0x01000000)
                  : Colors.black.withValues(alpha: 0.62),
            ),
          ),
        ),
        leanback
            ? Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
                  child: panel,
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: panel,
                ),
              ),
      ],
    );

    if (!tv) return body;

    // Per-row graph: ←/→ within a line; ↓ from Text Color → BG Opacity
    // (not reading-order into the next swatch).
    return TvOverlayScope(
      onDismiss: _close,
      autofocusFirst: false,
      debugLabel: 'player-sub-settings',
      child: ShellTvDisableLinearFocus(
        child: TvFocusGraph(
          tabId: PlayerSubtitleSettingsDialog.tvTabId,
          child: body,
        ),
      ),
    );
  }

  Widget _tvRow({
    required bool tv,
    required String rowId,
    required int sortOrder,
    required int itemCount,
    required Widget child,
  }) {
    if (!tv) return child;
    return TvKitRow(
      tabId: PlayerSubtitleSettingsDialog.tvTabId,
      rowId: rowId,
      sortOrder: sortOrder,
      itemCount: itemCount,
      child: child,
    );
  }

  Widget _buildFontChip(
    BuildContext context, {
    required bool tv,
    required String font,
    required int index,
  }) {
    final selected = _values.font == font;
    return _SelectFontChip(
      font: font,
      selected: selected,
      tv: tv,
      index: index,
      onSelect: () {
        _apply(() {
          _values = PlayerSubtitleSettingsValues(
            size: _values.size,
            delay: _values.delay,
            color: _values.color,
            bgOpacity: _values.bgOpacity,
            bottomPadding: _values.bottomPadding,
            bold: _values.bold,
            font: font,
          );
          SettingsService().setSubFont(font);
        });
      },
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
    this.tvRowId,
    this.listIndex,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String trailing;
  final ValueChanged<double> onChanged;
  final bool tvFocus;
  final bool autofocus;
  final String? tvRowId;
  final int? listIndex;

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

    return shellFocusableTap(
      context: context,
      onTap: () {},
      autoFocus: widget.autofocus,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      listIndex: widget.listIndex,
      tvTabId: PlayerSubtitleSettingsDialog.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.listIndex,
      tvZone: ShellTvZone.row,
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
        // ↑/↓ → graph moveVerticalInTab (next settings line).
        return KeyEventResult.ignored;
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
    this.listIndex,
  });

  final Color color;
  final bool selected;
  final bool tvFocus;
  final VoidCallback onSelect;
  final int? listIndex;

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
      listIndex: widget.listIndex,
      tvTabId: PlayerSubtitleSettingsDialog.tvTabId,
      tvRowId: PlayerSubtitleSettingsDialog.colorRowId,
      tvItemIndex: widget.listIndex,
      tvZone: ShellTvZone.chipStrip,
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
          listIndex: 0,
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
          listIndex: 1,
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
    this.listIndex,
  });

  final IconData icon;
  final bool tvFocus;
  final ValueChanged<int> onStep;
  final int? listIndex;

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
      listIndex: widget.listIndex,
      tvTabId: PlayerSubtitleSettingsDialog.tvTabId,
      tvRowId: PlayerSubtitleSettingsDialog.delayRowId,
      tvItemIndex: widget.listIndex,
      tvZone: ShellTvZone.chipStrip,
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
        Switch(
          value: bold,
          scale: Switch.settingsScale,
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
      listIndex: 0,
      tvTabId: PlayerSubtitleSettingsDialog.tvTabId,
      tvRowId: PlayerSubtitleSettingsDialog.boldRowId,
      tvItemIndex: 0,
      tvZone: ShellTvZone.row,
      child: row,
    );
  }
}

/// Green-border close — same recipe as [PlayerPopupPanel] chrome.
class _PopupSettingsCloseButton extends StatefulWidget {
  const _PopupSettingsCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PopupSettingsCloseButton> createState() =>
      _PopupSettingsCloseButtonState();
}

class _PopupSettingsCloseButtonState extends State<_PopupSettingsCloseButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final mouseHover = policy.scaleOnHover;
    final highlight = _hovered || _focused;
    final face = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? PlayerPopupTokens.accentFill : Colors.transparent,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        border: Border.all(
          color: highlight
              ? PlayerPopupTokens.accent
              : PlayerPopupTokens.accentBorder,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: const Icon(
        Icons.close_rounded,
        size: 14,
        color: PlayerPopupTokens.accent,
      ),
    );
    if (!tvFocus) {
      return MouseRegion(
        onEnter: (_) {
          if (mouseHover) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (mouseHover) setState(() => _hovered = false);
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
            hoverColor: PlayerPopupTokens.accentFill,
            child: face,
          ),
        ),
      );
    }
    return FocusableControl(
      onTap: widget.onTap,
      borderRadius: PlayerPopupTokens.chipRadius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: mouseHover ? (h) => setState(() => _hovered = h) : null,
      child: face,
    );
  }
}

/// Font pickers as select cards (same chrome as player menus).
class _SelectFontChip extends StatefulWidget {
  const _SelectFontChip({
    required this.font,
    required this.selected,
    required this.tv,
    required this.index,
    required this.onSelect,
  });

  final String font;
  final bool selected;
  final bool tv;
  final int index;
  final VoidCallback onSelect;

  @override
  State<_SelectFontChip> createState() => _SelectFontChipState();
}

class _SelectFontChipState extends State<_SelectFontChip> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final mouseHover =
        ShellScope.inputPolicyOf(context).scaleOnHover;
    final highlight = _hovered || _focused;
    final chrome = playerPopupSelectChrome(
      selected: widget.selected,
      highlight: highlight,
    );
    final face = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chrome.bg,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
        border: Border.all(color: chrome.border, width: chrome.borderWidth),
      ),
      child: Text(
        widget.font,
        style: TextStyle(
          color: chrome.labelFg,
          fontSize: 12,
          fontWeight:
              widget.selected || highlight ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );

    if (!widget.tv) {
      return MouseRegion(
        key: ValueKey('sub-font-${widget.font}'),
        onEnter: (_) {
          if (mouseHover) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (mouseHover) setState(() => _hovered = false);
        },
        child: GestureDetector(onTap: widget.onSelect, child: face),
      );
    }
    return KeyedSubtree(
      key: ValueKey('sub-font-${widget.font}'),
      child: shellFocusableTap(
        context: context,
        onTap: widget.onSelect,
        borderRadius: PlayerPopupTokens.cardRadius,
        scaleOnFocus: 1.0,
        showFocusBorder: false,
        showFocusFill: false,
        listIndex: widget.index,
        tvTabId: PlayerSubtitleSettingsDialog.tvTabId,
        tvRowId: PlayerSubtitleSettingsDialog.fontRowId,
        tvItemIndex: widget.index,
        tvZone: ShellTvZone.chipStrip,
        onFocusChange: (f) => setState(() => _focused = f),
        child: face,
      ),
    );
  }
}
