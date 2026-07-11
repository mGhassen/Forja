import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Blinking text caret for TV search browse mode.
class TvBlinkingCaret extends StatefulWidget {
  const TvBlinkingCaret({
    super.key,
    required this.active,
    required this.color,
    this.width = 2,
    this.height = 32,
  });

  final bool active;
  final Color color;
  final double width;
  final double height;

  @override
  State<TvBlinkingCaret> createState() => _TvBlinkingCaretState();
}

class _TvBlinkingCaretState extends State<TvBlinkingCaret> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    if (widget.active) _startBlink();
  }

  @override
  void didUpdateWidget(covariant TvBlinkingCaret oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _visible = true;
      _startBlink();
    } else if (!widget.active) {
      _stopBlink();
    }
  }

  void _startBlink() {
    _stopBlink();
    _timer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (!mounted) return;
      setState(() => _visible = !_visible);
    });
  }

  void _stopBlink() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopBlink();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 80),
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: const EdgeInsets.only(right: 2),
        color: widget.color,
      ),
    );
  }
}

/// Placeholder revealed one character at a time.
class TvTypewriterText extends StatefulWidget {
  const TvTypewriterText({
    super.key,
    required this.text,
    required this.active,
    required this.style,
  });

  final String text;
  final bool active;
  final TextStyle style;

  @override
  State<TvTypewriterText> createState() => _TvTypewriterTextState();
}

class _TvTypewriterTextState extends State<TvTypewriterText> {
  int _visibleChars = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _startTyping();
  }

  @override
  void didUpdateWidget(covariant TvTypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startTyping();
    } else if (!widget.active) {
      _stopTyping(reset: true);
    } else if (widget.active && widget.text != oldWidget.text) {
      _startTyping();
    }
  }

  void _startTyping() {
    _stopTyping(reset: true);
    if (widget.text.isEmpty) return;
    _timer = Timer.periodic(ShellTokens.navRailLabelLetterInterval, (_) {
      if (!mounted) return;
      if (_visibleChars >= widget.text.length) {
        _timer?.cancel();
        return;
      }
      setState(() => _visibleChars++);
    });
  }

  void _stopTyping({bool reset = false}) {
    _timer?.cancel();
    _timer = null;
    if (reset && _visibleChars != 0) {
      setState(() => _visibleChars = 0);
    }
  }

  @override
  void dispose() {
    _stopTyping();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && _visibleChars == 0) {
      return const SizedBox.shrink();
    }
    final end = _visibleChars.clamp(0, widget.text.length);
    return Text(
      widget.text.substring(0, end),
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }
}

/// TV browse-mode search placeholder: blinking caret + typewriter hint.
class TvSearchBrowsePlaceholder extends StatelessWidget {
  const TvSearchBrowsePlaceholder({
    super.key,
    required this.active,
    required this.placeholder,
    required this.hintStyle,
    this.caretColor,
    this.caretHeight,
  });

  final bool active;
  final String placeholder;
  final TextStyle hintStyle;
  final Color? caretColor;
  final double? caretHeight;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    final caret = caretColor ?? hintStyle.color ?? ForjaShellColors.textPrimary;
    final height = caretHeight ?? (hintStyle.fontSize ?? 16) * 1.15;
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TvBlinkingCaret(
            active: active,
            color: caret,
            height: height,
          ),
          Flexible(
            child: TvTypewriterText(
              text: placeholder,
              active: active,
              style: hintStyle,
            ),
          ),
        ],
      ),
    );
  }
}
