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
  /// Swallow the second letter after cycling multi-char on the first (FR → F cycles, ignore R).
  String? _suppressLetter;

  void reset() {
    _prefix = '';
    _lastMatchIndex = -1;
    _lastKeyTimeStamp = null;
    _suppressLetter = null;
  }

  /// Returns the next list index to jump to, or null when nothing matches.
  int? nextIndex({
    required String letter,
    required Duration timeStamp,
    required int itemCount,
    required String Function(int index) labelAt,
    int anchorIndex = -1,
  }) {
    if (itemCount <= 0 || letter.isEmpty) return null;

    if (_suppressLetter != null && letter == _suppressLetter) {
      _suppressLetter = null;
      _lastKeyTimeStamp = timeStamp;
      return _lastMatchIndex >= 0 ? _lastMatchIndex : null;
    }

    final expired = _lastKeyTimeStamp == null ||
        timeStamp - _lastKeyTimeStamp! > bufferTimeout;

    final cycleSameLetter = !expired &&
        _prefix.length == 1 &&
        _prefix == letter &&
        _lastMatchIndex >= 0;

    final cycleMultiPrefix = !expired &&
        _prefix.length > 1 &&
        _lastMatchIndex >= 0 &&
        letter == _prefix[0];

    if (expired) {
      _prefix = letter;
      _lastMatchIndex = -1;
      _suppressLetter = null;
    } else if (cycleSameLetter) {
      _suppressLetter = null;
    } else if (cycleMultiPrefix) {
      _suppressLetter = _prefix.length > 1 ? _prefix[1] : null;
    } else {
      _prefix += letter;
      _lastMatchIndex = -1;
      _suppressLetter = null;
    }

    _lastKeyTimeStamp = timeStamp;

    final cycling = cycleSameLetter || cycleMultiPrefix;
    final int searchStart;
    final bool wrapBefore;
    if (cycling) {
      searchStart = _lastMatchIndex;
      wrapBefore = false;
    } else if (expired) {
      searchStart = anchorIndex.clamp(-1, itemCount - 1);
      wrapBefore = true;
    } else {
      searchStart = -1;
      wrapBefore = false;
    }

    final match = _findMatch(
      prefix: _prefix,
      itemCount: itemCount,
      labelAt: labelAt,
      startAfter: searchStart,
      wrapBefore: wrapBefore,
      stayOnNoNext: cycling,
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
    int anchorIndex = -1,
  }) {
    int? last;
    for (var i = 0; i < letters.length; i++) {
      final idx = nextIndex(
        letter: letters[i],
        timeStamp: timeStamp + Duration(microseconds: i),
        itemCount: itemCount,
        labelAt: labelAt,
        anchorIndex: anchorIndex,
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
    required bool wrapBefore,
    required bool stayOnNoNext,
  }) {
    final p = prefix.toLowerCase();
    if (p.isEmpty) return null;

    for (var i = startAfter + 1; i < itemCount; i++) {
      if (_labelMatches(labelAt(i), p)) return i;
    }

    if (wrapBefore && startAfter >= 0) {
      for (var i = 0; i <= startAfter; i++) {
        if (_labelMatches(labelAt(i), p)) return i;
      }
    }

    if (stayOnNoNext &&
        startAfter >= 0 &&
        _labelMatches(labelAt(startAfter), p)) {
      return startAfter;
    }

    if (startAfter < 0) {
      for (var i = 0; i < itemCount; i++) {
        if (_labelMatches(labelAt(i), p)) return i;
      }
    }
    return null;
  }

  /// Single letter: name starts with that letter (after leading junk).
  /// Multi-letter: token match (`| FR`, `FRANCE`, not `afr` inside `AFRICA`).
  static bool _labelMatches(String label, String prefix) {
    if (prefix.isEmpty) return false;
    if (prefix.length == 1) {
      final normalized = _normalizedLabelStart(label);
      return normalized.isNotEmpty && normalized.startsWith(prefix);
    }
    return _labelContainsToken(label, prefix);
  }

  static bool _labelContainsToken(String label, String prefix) {
    final lower = label.trim().toLowerCase();
    final escaped = RegExp.escape(prefix);
    return RegExp('(^|[^a-z])$escaped').hasMatch(lower);
  }

  static String _normalizedLabelStart(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'[a-zA-Z]').firstMatch(trimmed);
    if (match == null) return trimmed.toLowerCase();
    return trimmed.substring(match.start).toLowerCase();
  }

  static String? _logicalLetter(LogicalKeyboardKey key) {
    for (final (logical, letter) in _logicalLetters) {
      if (key == logical) return letter;
    }
    final label = key.keyLabel;
    if (label.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(label)) {
      return label.toLowerCase();
    }
    return null;
  }

  static const _logicalLetters = <(LogicalKeyboardKey, String)>[
    (LogicalKeyboardKey.keyA, 'a'),
    (LogicalKeyboardKey.keyB, 'b'),
    (LogicalKeyboardKey.keyC, 'c'),
    (LogicalKeyboardKey.keyD, 'd'),
    (LogicalKeyboardKey.keyE, 'e'),
    (LogicalKeyboardKey.keyF, 'f'),
    (LogicalKeyboardKey.keyG, 'g'),
    (LogicalKeyboardKey.keyH, 'h'),
    (LogicalKeyboardKey.keyI, 'i'),
    (LogicalKeyboardKey.keyJ, 'j'),
    (LogicalKeyboardKey.keyK, 'k'),
    (LogicalKeyboardKey.keyL, 'l'),
    (LogicalKeyboardKey.keyM, 'm'),
    (LogicalKeyboardKey.keyN, 'n'),
    (LogicalKeyboardKey.keyO, 'o'),
    (LogicalKeyboardKey.keyP, 'p'),
    (LogicalKeyboardKey.keyQ, 'q'),
    (LogicalKeyboardKey.keyR, 'r'),
    (LogicalKeyboardKey.keyS, 's'),
    (LogicalKeyboardKey.keyT, 't'),
    (LogicalKeyboardKey.keyU, 'u'),
    (LogicalKeyboardKey.keyV, 'v'),
    (LogicalKeyboardKey.keyW, 'w'),
    (LogicalKeyboardKey.keyX, 'x'),
    (LogicalKeyboardKey.keyY, 'y'),
    (LogicalKeyboardKey.keyZ, 'z'),
  ];

  /// Desktop keys often have null [KeyEvent.character] without a text field.
  static String? lettersFromKeyDown(KeyDownEvent event) {
    final logical = _logicalLetter(event.logicalKey);
    if (logical != null) return logical;

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      final letters = char.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (letters.isNotEmpty) return letters;
    }
    return null;
  }
}

/// Desktop: hover a vertical list and type letters to scroll by name prefix.
///
/// - Single letter jumps to the first matching row after [anchorIndex]; repeat
///   the letter quickly for the next match (no wrap at the end).
/// - Quick multi-letter typing (`fr`) matches a token in the label (`EU | FRANCE`,
///   `EU | FR - live`) — not letters buried inside a word (`AFRICA`).
/// - Repeat the same multi-letter prefix quickly (`fr` then `f` again) cycles to
///   the next match.
class ListLetterJumpScope extends StatefulWidget {
  const ListLetterJumpScope({
    super.key,
    required this.enabled,
    required this.itemCount,
    required this.labelAt,
    required this.onJump,
    required this.child,
    this.anchorIndex = -1,
  });

  final bool enabled;
  final int itemCount;
  final String Function(int index) labelAt;
  final ValueChanged<int> onJump;
  final Widget child;

  /// List index to continue from on a fresh letter (usually the focused row).
  final int anchorIndex;

  @override
  State<ListLetterJumpScope> createState() => _ListLetterJumpScopeState();
}

class _ListLetterJumpScopeState extends State<ListLetterJumpScope> {
  final _matcher = ListLetterJumpMatcher();
  final _focusNode = FocusNode(debugLabel: 'list-letter-jump');
  bool _hovered = false;
  Timer? _hoverExitTimer;

  @override
  void dispose() {
    _hoverExitTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onFocusKey(FocusNode node, KeyEvent event) {
    if (!_hovered || !widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final letters = ListLetterJumpMatcher.lettersFromKeyDown(event);
    if (letters == null || letters.isEmpty) return KeyEventResult.ignored;

    final index = _matcher.nextIndices(
      letters: letters,
      timeStamp: event.timeStamp,
      itemCount: widget.itemCount,
      labelAt: widget.labelAt,
      anchorIndex: widget.anchorIndex,
    );
    if (index == null) return KeyEventResult.ignored;
    widget.onJump(index);
    return KeyEventResult.handled;
  }

  @override
  void didUpdateWidget(covariant ListLetterJumpScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _matcher.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.enabled,
      onKeyEvent: _onFocusKey,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        onEnter: (_) {
          _hoverExitTimer?.cancel();
          _hovered = true;
          if (widget.enabled && widget.itemCount > 0) {
            _focusNode.requestFocus();
          }
        },
        onExit: (_) {
          _hoverExitTimer?.cancel();
          _hoverExitTimer = Timer(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            _hovered = false;
            _matcher.reset();
            if (_focusNode.hasFocus) {
              _focusNode.unfocus();
            }
          });
        },
        child: widget.child,
      ),
    );
  }
}
