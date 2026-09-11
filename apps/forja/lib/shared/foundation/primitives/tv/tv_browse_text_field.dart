import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/foundation/primitives/shell/forja_shell_scope.dart';
import 'package:forja/shared/foundation/primitives/tv/tv_search_browse_overlay.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';

/// Leanback TV only — desktop has arrow-key focus too but should type immediately.
bool shellTvBrowseSearch(BuildContext context) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  if (policy != null) {
    return policy.useFocusableMoodChips && !policy.scaleOnHover;
  }
  return ShellTokens.isAndroidTvDevice;
}

/// TV search field: focusable in browse mode; Enter/Select opens the keyboard.
///
/// Browse D-pad must not rely on [FocusNode.onKeyEvent] alone. [TextField]
/// maps arrows to selection / [DirectionalFocusAction.forTextField] intents
/// (ignoreTextFields) via [DefaultTextEditingShortcuts], which consume keys
/// without moving focus. Parent [Actions] override those intents while
/// browsing so ↓/→ reach the panel graph (episode list, filters, …).
class TvBrowseTextField extends StatefulWidget {
  const TvBrowseTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.decoration,
    this.style,
    this.autofocus = false,
    this.onEscape,
    this.onKeyEvent,
    this.onSubmitted,
    this.browsePlaceholder,
    this.browseHintStyle,
    this.caretHeight,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final TextStyle? style;
  final bool autofocus;
  final VoidCallback? onEscape;
  final FocusOnKeyEventCallback? onKeyEvent;
  final ValueChanged<String>? onSubmitted;
  final String? browsePlaceholder;
  final TextStyle? browseHintStyle;
  final double? caretHeight;

  @override
  State<TvBrowseTextField> createState() => TvBrowseTextFieldState();
}

class TvBrowseTextFieldState extends State<TvBrowseTextField> {
  bool _editing = false;
  FocusOnKeyEventCallback? _previousKeyHandler;

  bool get _tvBrowse => shellTvBrowseSearch(context);

  bool get _browseOnly => _tvBrowse && !_editing;

  /// True while the soft keyboard / edit mode is active.
  bool get isEditing => _editing;

  String get _placeholder =>
      widget.browsePlaceholder ??
      widget.decoration.hintText ??
      '';

  TextStyle get _hintStyle =>
      widget.browseHintStyle ??
      widget.decoration.hintStyle ??
      const TextStyle(color: Colors.white38);

  @override
  void initState() {
    super.initState();
    _bindKeyHandler(widget.focusNode);
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant TvBrowseTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      oldWidget.focusNode.onKeyEvent = _previousKeyHandler;
      _bindKeyHandler(widget.focusNode);
      widget.focusNode.addListener(_onFocusChange);
    } else {
      // EditableText Focus.attach can race hot reload / remount — keep ours.
      _ensureKeyHandler();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.focusNode.onKeyEvent = _previousKeyHandler;
    super.dispose();
  }

  void _bindKeyHandler(FocusNode node) {
    _previousKeyHandler = node.onKeyEvent;
    node.onKeyEvent = _handleKey;
  }

  void _ensureKeyHandler() {
    if (widget.focusNode.onKeyEvent != _handleKey) {
      _previousKeyHandler = widget.focusNode.onKeyEvent;
      widget.focusNode.onKeyEvent = _handleKey;
    }
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && _editing && mounted) {
      setState(() => _editing = false);
    } else if (mounted) {
      setState(() {});
    }
  }

  /// Open the keyboard / edit mode (TV: after OK on the browse field).
  void beginEditing() => _beginEditing();

  /// Leave edit mode; keep focus so the field stays in browse highlight.
  void endEditing({bool keepFocus = true}) {
    if (!_editing) {
      if (keepFocus && !widget.focusNode.hasFocus) {
        widget.focusNode.requestFocus();
      }
      return;
    }
    if (mounted) setState(() => _editing = false);
    if (keepFocus && !widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
  }

  void _beginEditing() {
    if (!_editing && mounted) {
      setState(() => _editing = true);
    }
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    _ensureKeyHandler();
    if (_browseOnly && shellTvIsActivateKey(event)) {
      _beginEditing();
      return KeyEventResult.handled;
    }

    final chained = widget.onKeyEvent?.call(node, event);
    if (chained == KeyEventResult.handled) return KeyEventResult.handled;

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack)) {
      if (widget.onEscape != null) {
        widget.onEscape!();
        return KeyEventResult.handled;
      }
      if (_editing) {
        setState(() => _editing = false);
        return KeyEventResult.handled;
      }
    }

    return chained ?? KeyEventResult.ignored;
  }

  void _onFieldSubmitted(String value) {
    // Dismiss keyboard mode but keep browse focus for the parent to redirect.
    endEditing(keepFocus: true);
    widget.onSubmitted?.call(value);
  }

  /// Synthesize a key for [widget.onKeyEvent] from selection / directional intents.
  KeyEventResult _dispatchLogicalKey(LogicalKeyboardKey key) {
    final physical = switch (key) {
      LogicalKeyboardKey.arrowLeft => PhysicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight => PhysicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp => PhysicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown => PhysicalKeyboardKey.arrowDown,
      _ => PhysicalKeyboardKey.arrowDown,
    };
    final event = KeyDownEvent(
      physicalKey: physical,
      logicalKey: key,
      timeStamp: Duration.zero,
      synthesized: true,
    );
    return _handleKey(widget.focusNode, event);
  }

  Map<Type, Action<Intent>> _browseActions() {
    return <Type, Action<Intent>>{
      ExtendSelectionByCharacterIntent:
          _BrowseOrDeferAction<ExtendSelectionByCharacterIntent>(
        shouldIntercept: () => _browseOnly,
        onIntercept: (intent) {
          _dispatchLogicalKey(
            intent.forward
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
        },
      ),
      ExtendSelectionVerticallyToAdjacentLineIntent:
          _BrowseOrDeferAction<ExtendSelectionVerticallyToAdjacentLineIntent>(
        shouldIntercept: () => _browseOnly,
        onIntercept: (intent) {
          _dispatchLogicalKey(
            intent.forward
                ? LogicalKeyboardKey.arrowDown
                : LogicalKeyboardKey.arrowUp,
          );
        },
      ),
      DirectionalFocusIntent: _BrowseOrDeferAction<DirectionalFocusIntent>(
        shouldIntercept: () => _browseOnly,
        onIntercept: (intent) {
          final key = switch (intent.direction) {
            TraversalDirection.left => LogicalKeyboardKey.arrowLeft,
            TraversalDirection.right => LogicalKeyboardKey.arrowRight,
            TraversalDirection.up => LogicalKeyboardKey.arrowUp,
            TraversalDirection.down => LogicalKeyboardKey.arrowDown,
          };
          _dispatchLogicalKey(key);
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    _ensureKeyHandler();
    final showBrowsePlaceholder =
        _browseOnly && widget.focusNode.hasFocus && widget.controller.text.isEmpty;
    // copyWith(hintText: null) keeps the old hint - empty string hides it.
    final decoration = widget.decoration.copyWith(
      hintText: showBrowsePlaceholder ? '' : widget.decoration.hintText,
    );
    final contentPad =
        decoration.contentPadding?.resolve(Directionality.of(context));
    final overlayLeft =
        decoration.prefixIcon != null ? 48.0 : (contentPad?.left ?? 16.0);
    final overlayRight = contentPad?.right ?? 16.0;

    Widget field = Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus && !_tvBrowse,
          readOnly: _browseOnly,
          showCursor: !_browseOnly || widget.controller.text.isNotEmpty,
          enableInteractiveSelection: !_browseOnly,
          onChanged: widget.onChanged,
          onSubmitted: _onFieldSubmitted,
          textInputAction: TextInputAction.search,
          style: widget.style,
          decoration: decoration,
        ),
        if (showBrowsePlaceholder && _placeholder.isNotEmpty)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(left: overlayLeft, right: overlayRight),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TvSearchBrowsePlaceholder(
                  active: true,
                  placeholder: _placeholder,
                  hintStyle: _hintStyle,
                  caretHeight: widget.caretHeight,
                ),
              ),
            ),
          ),
      ],
    );

    if (_tvBrowse) {
      // Override EditableText selection / directional intents while browsing.
      field = Actions(actions: _browseActions(), child: field);
    }
    return field;
  }
}

/// Parent override for EditableText's overridable selection / focus actions.
class _BrowseOrDeferAction<T extends Intent> extends Action<T> {
  _BrowseOrDeferAction({
    required this.shouldIntercept,
    required this.onIntercept,
  });

  final bool Function() shouldIntercept;
  final void Function(T intent) onIntercept;

  @override
  Object? invoke(T intent) {
    if (shouldIntercept()) {
      onIntercept(intent);
      return null;
    }
    return callingAction?.invoke(intent);
  }

  @override
  bool consumesKey(T intent) {
    if (shouldIntercept()) return true;
    return callingAction?.consumesKey(intent) ?? true;
  }
}
