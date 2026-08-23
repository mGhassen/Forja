import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/tv_search_browse_overlay.dart';

/// Leanback TV only — desktop has arrow-key focus too but should type immediately.
bool shellTvBrowseSearch(BuildContext context) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  if (policy != null) {
    return policy.useFocusableMoodChips && !policy.scaleOnHover;
  }
  return ShellTokens.isAndroidTvDevice;
}

/// TV search field: focusable in browse mode; Enter/Select opens the keyboard.
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
    _previousKeyHandler = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _handleKey;
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant TvBrowseTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      oldWidget.focusNode.onKeyEvent = _previousKeyHandler;
      _previousKeyHandler = widget.focusNode.onKeyEvent;
      widget.focusNode.onKeyEvent = _handleKey;
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.focusNode.onKeyEvent = _previousKeyHandler;
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
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

    return Stack(
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
  }
}
