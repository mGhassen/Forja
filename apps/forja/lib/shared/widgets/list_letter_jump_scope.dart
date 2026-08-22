import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prefix matcher for type-to-scroll lists (Windows Explorer style).
class ListLetterJumpMatcher {
  ListLetterJumpMatcher({
    this.bufferTimeout = const Duration(milliseconds: 1000),
  });

  final Duration bufferTimeout;

  String _prefix = '';
  int _lastMatchIndex = -1;
  DateTime? _lastKeyTime;

  void reset() {
    _prefix = '';
    _lastMatchIndex = -1;
    _lastKeyTime = null;
  }

  /// Returns the next list index to jump to, or null when nothing matches.
  int? nextIndex({
    required String letter,
    required int itemCount,
    required String Function(int index) labelAt,
  }) {
    if (itemCount <= 0) return null;

    final now = DateTime.now();
    final expired = _lastKeyTime == null ||
        now.difference(_lastKeyTime!) > bufferTimeout;

    final cycleSameLetter = !expired &&
        _prefix.length == 1 &&
        _prefix == letter &&
        _lastMatchIndex >= 0;

    if (expired) {
      _prefix = letter;
      _lastMatchIndex = -1;
    } else if (cycleSameLetter) {
      // Repeated single letter — next row with that prefix.
    } else {
      _prefix += letter;
      _lastMatchIndex = -1;
    }

    _lastKeyTime = now;

    final startAfter = cycleSameLetter ? _lastMatchIndex : -1;
    final match = _findMatch(
      prefix: _prefix,
      itemCount: itemCount,
      labelAt: labelAt,
      startAfter: startAfter,
    );
    if (match == null) return null;
    _lastMatchIndex = match;
    return match;
  }

  static int? _findMatch({
    required String prefix,
    required int itemCount,
    required String Function(int index) labelAt,
    required int startAfter,
  }) {
    final p = prefix.toLowerCase();
    if (p.isEmpty) return null;

    for (var i = startAfter + 1; i < itemCount; i++) {
      if (_labelStartsWith(labelAt(i), p)) return i;
    }
    for (var i = 0; i <= startAfter; i++) {
      if (_labelStartsWith(labelAt(i), p)) return i;
    }
    return null;
  }

  static String _normalizedLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'[a-zA-Z]').firstMatch(trimmed);
    if (match == null) return trimmed.toLowerCase();
    return trimmed.substring(match.start).toLowerCase();
  }

  static bool _labelStartsWith(String label, String prefix) {
    final normalized = _normalizedLabel(label);
    return normalized.isNotEmpty && normalized.startsWith(prefix);
  }
}

/// Desktop: hover a vertical list and type letters to scroll by name prefix.
///
/// - Single letter jumps to the first matching row; repeat the letter quickly
///   for the next match.
/// - Quick multi-letter typing (e.g. USA, FRA) matches longer prefixes.
class ListLetterJumpScope extends StatefulWidget {
  const ListLetterJumpScope({
    super.key,
    required this.enabled,
    required this.itemCount,
    required this.labelAt,
    required this.onJump,
    required this.child,
  });

  final bool enabled;
  final int itemCount;
  final String Function(int index) labelAt;
  final ValueChanged<int> onJump;
  final Widget child;

  @override
  State<ListLetterJumpScope> createState() => _ListLetterJumpScopeState();
}

class _ListLetterJumpScopeState extends State<ListLetterJumpScope> {
  final _matcher = ListLetterJumpMatcher();
  bool _hovered = false;
  bool _handlerBound = false;

  @override
  void dispose() {
    _unbindHandler();
    super.dispose();
  }

  void _bindHandler() {
    if (_handlerBound) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _handlerBound = true;
  }

  void _unbindHandler() {
    if (!_handlerBound) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _handlerBound = false;
  }

  bool _onKey(KeyEvent event) {
    if (!widget.enabled || !_hovered) return false;
    if (event is! KeyDownEvent) return false;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return false;
    }

    final char = event.character;
    if (char == null || char.length != 1) return false;
    final letter = char.toLowerCase();
    if (letter == letter.toUpperCase()) return false;

    final index = _matcher.nextIndex(
      letter: letter,
      itemCount: widget.itemCount,
      labelAt: widget.labelAt,
    );
    if (index == null) return false;
    widget.onJump(index);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _hovered = true;
        _bindHandler();
      },
      onExit: (_) {
        _hovered = false;
        _unbindHandler();
        _matcher.reset();
      },
      child: widget.child,
    );
  }
}
