import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prefix matcher for type-to-scroll lists (Windows Explorer style).
class ListLetterJumpMatcher {
  ListLetterJumpMatcher({
    this.bufferTimeout = const Duration(milliseconds: 1500),
  });

  final Duration bufferTimeout;

  String _prefix = '';
  int _lastMatchIndex = -1;
  Duration? _lastKeyTimeStamp;

  void reset() {
    _prefix = '';
    _lastMatchIndex = -1;
    _lastKeyTimeStamp = null;
  }

  /// Returns the next list index to jump to, or null when nothing matches.
  int? nextIndex({
    required String letter,
    required Duration timeStamp,
    required int itemCount,
    required String Function(int index) labelAt,
  }) {
    if (itemCount <= 0 || letter.isEmpty) return null;

    final expired = _lastKeyTimeStamp == null ||
        timeStamp - _lastKeyTimeStamp! > bufferTimeout;

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

    _lastKeyTimeStamp = timeStamp;

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

  /// Apply a run of letters from one key event (fast multi-key bursts).
  int? nextIndices({
    required String letters,
    required Duration timeStamp,
    required int itemCount,
    required String Function(int index) labelAt,
  }) {
    int? last;
    for (var i = 0; i < letters.length; i++) {
      final idx = nextIndex(
        letter: letters[i],
        timeStamp: timeStamp + Duration(microseconds: i),
        itemCount: itemCount,
        labelAt: labelAt,
      );
      if (idx != null) last = idx;
    }
    return last;
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

  /// [KeyEvent.character] is often null on desktop without a focused text field.
  static String? lettersFromKeyDown(KeyDownEvent event) {
    final char = event.character;
    if (char != null && char.isNotEmpty) {
      final letters = char.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (letters.isNotEmpty) return letters;
    }
    final label = event.logicalKey.keyLabel;
    if (label.length == 1) {
      final ch = label.toLowerCase();
      if (ch != ch.toUpperCase()) return ch;
    }
    return null;
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
  Timer? _hoverExitTimer;

  @override
  void dispose() {
    _hoverExitTimer?.cancel();
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

    final letters = ListLetterJumpMatcher.lettersFromKeyDown(event);
    if (letters == null || letters.isEmpty) return false;

    final index = _matcher.nextIndices(
      letters: letters,
      timeStamp: event.timeStamp,
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
      hitTestBehavior: HitTestBehavior.translucent,
      onEnter: (_) {
        _hoverExitTimer?.cancel();
        _hovered = true;
        _bindHandler();
      },
      onExit: (_) {
        // Scroll / focus nudges can flicker hover off between fast key presses.
        _hoverExitTimer?.cancel();
        _hoverExitTimer = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          _hovered = false;
          _unbindHandler();
          _matcher.reset();
        });
      },
      child: widget.child,
    );
  }
}
