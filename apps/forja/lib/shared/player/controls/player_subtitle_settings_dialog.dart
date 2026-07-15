import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_seek_scrub_cancel.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
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

/// Subtitle appearance dialog — touch + TV D-pad (sliders, chips, toggles).
class PlayerSubtitleSettingsDialog {
  static bool _isShowing = false;
  static VoidCallback? _dismiss;
  static bool get isShowing => _isShowing;

  static bool dismissIfShowing() {
    if (!_isShowing || _dismiss == null) return false;
    _dismiss!();
    return true;
  }

  static Future<void> show(
    BuildContext context, {
    required PlayerSubtitleSettingsValues initial,
    required void Function(PlayerSubtitleSettingsValues values) onChanged,
    Player? player,
  }) {
    _isShowing = true;
    playerChromeCancelSeekScrubs();
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        var values = initial;

        return StatefulBuilder(
          builder: (context, setDialog) {
            final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

            void apply(void Function() mutate) {
              setDialog(() => mutate());
              onChanged(values);
            }

            void close() {
              SettingsService().setSubSize(values.size);
              SettingsService().setSubBgOpacity(values.bgOpacity);
              SettingsService().setSubBottomPadding(values.bottomPadding);
              Navigator.pop(dialogContext);
            }

            _dismiss = close;

            Widget dialogBody = Dialog(
              backgroundColor: const Color(0xFF141414),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width * 0.9)
                      .clamp(280.0, 420.0),
                  maxHeight: MediaQuery.sizeOf(context).height * 0.8,
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
                          ForjaCloseButton.compact(
                            onTap: close,
                          ),
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
                              value: values.size,
                              min: 10,
                              max: 50,
                              trailing: '${values.size.toInt()}',
                              tvFocus: tv,
                              onChanged: (v) => apply(() => values =
                                  PlayerSubtitleSettingsValues(
                                    size: v,
                                    delay: values.delay,
                                    color: values.color,
                                    bgOpacity: values.bgOpacity,
                                    bottomPadding: values.bottomPadding,
                                    bold: values.bold,
                                    font: values.font,
                                  )),
                            ),
                            const SizedBox(height: 8),
                            _DelayRow(
                              delay: values.delay,
                              tvFocus: tv,
                              onChanged: (d) {
                                apply(() => values =
                                    PlayerSubtitleSettingsValues(
                                      size: values.size,
                                      delay: d,
                                      color: values.color,
                                      bgOpacity: values.bgOpacity,
                                      bottomPadding: values.bottomPadding,
                                      bold: values.bold,
                                      font: values.font,
                                    ));
                                _applyDelay(player, d);
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
                              children: _colorOptions.entries.map((e) {
                                final selected =
                                    values.color.toARGB32() ==
                                    e.value.toARGB32();
                                final swatch = Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: e.value,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? ForjaShellColors.brandGreen
                                          : Colors.white24,
                                      width: selected ? 3 : 1,
                                    ),
                                  ),
                                  child: selected
                                      ? Icon(
                                          Icons.check,
                                          size: 16,
                                          color: ForjaShellColors.brandGreen,
                                        )
                                      : null,
                                );
                                if (!tv) {
                                  return GestureDetector(
                                    onTap: () {
                                      apply(() {
                                        values =
                                            PlayerSubtitleSettingsValues(
                                          size: values.size,
                                          delay: values.delay,
                                          color: e.value,
                                          bgOpacity: values.bgOpacity,
                                          bottomPadding:
                                              values.bottomPadding,
                                          bold: values.bold,
                                          font: values.font,
                                        );
                                        SettingsService()
                                            .setSubColor(e.value.toARGB32());
                                      });
                                    },
                                    child: swatch,
                                  );
                                }
                                return shellFocusableTap(
                                  context: context,
                                  onTap: () {
                                    apply(() {
                                      values = PlayerSubtitleSettingsValues(
                                        size: values.size,
                                        delay: values.delay,
                                        color: e.value,
                                        bgOpacity: values.bgOpacity,
                                        bottomPadding: values.bottomPadding,
                                        bold: values.bold,
                                        font: values.font,
                                      );
                                      SettingsService()
                                          .setSubColor(e.value.toARGB32());
                                    });
                                  },
                                  borderRadius: 17,
                                  showFocusBorder: true,
                                  child: swatch,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            _SubSlider(
                              label: 'BG Opacity',
                              value: values.bgOpacity,
                              min: 0,
                              max: 1,
                              trailing:
                                  '${(values.bgOpacity * 100).toInt()}%',
                              tvFocus: tv,
                              onChanged: (v) => apply(() => values =
                                  PlayerSubtitleSettingsValues(
                                    size: values.size,
                                    delay: values.delay,
                                    color: values.color,
                                    bgOpacity: v,
                                    bottomPadding: values.bottomPadding,
                                    bold: values.bold,
                                    font: values.font,
                                  )),
                            ),
                            const SizedBox(height: 8),
                            _SubSlider(
                              label: 'Position',
                              value: values.bottomPadding,
                              min: 0,
                              max: 120,
                              trailing:
                                  '${values.bottomPadding.toInt()}',
                              tvFocus: tv,
                              onChanged: (v) => apply(() => values =
                                  PlayerSubtitleSettingsValues(
                                    size: values.size,
                                    delay: values.delay,
                                    color: values.color,
                                    bgOpacity: values.bgOpacity,
                                    bottomPadding: v,
                                    bold: values.bold,
                                    font: values.font,
                                  )),
                            ),
                            const SizedBox(height: 8),
                            _BoldRow(
                              bold: values.bold,
                              tvFocus: tv,
                              onChanged: (v) {
                                apply(() => values =
                                    PlayerSubtitleSettingsValues(
                                      size: values.size,
                                      delay: values.delay,
                                      color: values.color,
                                      bgOpacity: values.bgOpacity,
                                      bottomPadding: values.bottomPadding,
                                      bold: v,
                                      font: values.font,
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
                              children: _fonts.map((f) {
                                final selected = values.font == f;
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
                                    onTap: () {
                                      apply(() {
                                        values =
                                            PlayerSubtitleSettingsValues(
                                          size: values.size,
                                          delay: values.delay,
                                          color: values.color,
                                          bgOpacity: values.bgOpacity,
                                          bottomPadding:
                                              values.bottomPadding,
                                          bold: values.bold,
                                          font: f,
                                        );
                                        SettingsService().setSubFont(f);
                                      });
                                    },
                                    child: chip,
                                  );
                                }
                                return shellFocusableTap(
                                  context: context,
                                  onTap: () {
                                    apply(() {
                                      values = PlayerSubtitleSettingsValues(
                                        size: values.size,
                                        delay: values.delay,
                                        color: values.color,
                                        bgOpacity: values.bgOpacity,
                                        bottomPadding: values.bottomPadding,
                                        bold: values.bold,
                                        font: f,
                                      );
                                      SettingsService().setSubFont(f);
                                    });
                                  },
                                  borderRadius: 8,
                                  showFocusBorder: true,
                                  child: chip,
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
            );

            if (!tv) return dialogBody;

            return FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (!shellTvIsNavigationKey(event)) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.escape ||
                      event.logicalKey == LogicalKeyboardKey.goBack) {
                    close();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: dialogBody,
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _isShowing = false;
      _dismiss = null;
    });
  }

  static void _applyDelay(Player? player, double delay) {
    if (player?.platform is NativePlayer) {
      (player!.platform as NativePlayer).setProperty(
        'sub-delay',
        delay.toString(),
      );
    }
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

class _SubSlider extends StatefulWidget {
  const _SubSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.trailing,
    required this.onChanged,
    required this.tvFocus,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String trailing;
  final ValueChanged<double> onChanged;
  final bool tvFocus;

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
                color: _focused && widget.tvFocus
                    ? ForjaShellColors.brandGreen
                    : Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: _focused && widget.tvFocus ? 4 : 3,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: _focused && widget.tvFocus ? 8 : 7,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: _focused && widget.tvFocus
                ? ForjaShellColors.brandGreen
                : const Color(0xFF7C3AED),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: _focused && widget.tvFocus
                ? ForjaShellColors.brandGreen
                : const Color(0xFF7C3AED),
          ),
          child: Slider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );

    if (!widget.tvFocus) return slider;

    return Focus(
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

class _DelayRow extends StatelessWidget {
  const _DelayRow({
    required this.delay,
    required this.onChanged,
    required this.tvFocus,
  });

  final double delay;
  final ValueChanged<double> onChanged;
  final bool tvFocus;

  @override
  Widget build(BuildContext context) {
    void bump(double delta) {
      onChanged(double.parse((delay + delta).toStringAsFixed(1)));
    }

    Widget iconBtn({
      required IconData icon,
      required VoidCallback onTap,
    }) {
      final btn = IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        visualDensity: VisualDensity.compact,
        onPressed: tvFocus ? null : onTap,
      );
      if (!tvFocus) return btn;
      return shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: 18,
        showFocusBorder: true,
        child: btn,
      );
    }

    return Row(
      children: [
        const Text(
          'Delay',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const Spacer(),
        iconBtn(icon: Icons.remove, onTap: () => bump(-0.1)),
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
        iconBtn(icon: Icons.add, onTap: () => bump(0.1)),
      ],
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
          activeThumbColor: ForjaShellColors.brandGreen,
          onChanged: tvFocus ? null : onChanged,
        ),
      ],
    );
    if (!tvFocus) return row;
    return shellFocusableTap(
      context: context,
      onTap: () => onChanged(!bold),
      borderRadius: 8,
      showFocusBorder: true,
      child: row,
    );
  }
}
