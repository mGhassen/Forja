import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

enum ForjaToastKind { success, error, warning, info }

class ForjaToastEntry {
  ForjaToastEntry({
    required this.id,
    required this.message,
    required this.kind,
    required this.duration,
    this.actionLabel,
    this.onAction,
    this.tag,
  });

  final String id;
  final String message;
  final ForjaToastKind kind;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional stable key — [ForjaToast.dismissTag] / replace on re-show.
  final String? tag;

  bool get isTimed => duration > Duration.zero;
  bool get hasAction => actionLabel != null && onAction != null;
}

class _QueuedToast {
  const _QueuedToast({
    required this.message,
    required this.kind,
    required this.duration,
    this.actionLabel,
    this.onAction,
    this.tag,
  });

  final String message;
  final ForjaToastKind kind;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? tag;
}

/// Well-known toast tags (dismiss / replace).
abstract final class ForjaToastTags {
  static const packUpdates = 'pack-updates';
}

/// Top-right floating status toasts. Mount [ForjaToastHost] once at app root.
///
/// Pass [duration] `Duration.zero` to keep the toast until the user closes it
/// or taps its action (sticky — no auto-dismiss timer).
///
/// Timed toasts stack in a column (max 4). Hover pauses the dismiss progress
/// bar. Sticky (duration zero) stay put when trimming.
abstract final class ForjaToast {
  static final ForjaToastController controller = ForjaToastController();

  static void show(
    String message, {
    ForjaToastKind kind = ForjaToastKind.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    String? tag,
  }) {
    controller.show(
      message,
      kind: kind,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      tag: tag,
    );
  }

  static void success(
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    String? tag,
  }) =>
      show(
        message,
        kind: ForjaToastKind.success,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        tag: tag,
      );

  static void error(
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    String? tag,
  }) =>
      show(
        message,
        kind: ForjaToastKind.error,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        tag: tag,
      );

  static void warning(
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    String? tag,
  }) =>
      show(
        message,
        kind: ForjaToastKind.warning,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        tag: tag,
      );

  static void info(
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    String? tag,
  }) =>
      show(
        message,
        kind: ForjaToastKind.info,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        tag: tag,
      );

  /// Drop visible + queued toasts with [tag].
  static void dismissTag(String tag) => controller.dismissTag(tag);
}

class ForjaToastController extends ChangeNotifier {
  static const int maxVisible = 4;

  final List<ForjaToastEntry> _entries = [];
  final List<_QueuedToast> _queued = [];
  int _seq = 0;
  bool _suppress = false;
  bool _flushScheduled = false;

  List<ForjaToastEntry> get entries => List.unmodifiable(_entries);

  /// When true, [show] queues until suppress clears (e.g. intro splash).
  bool get suppress => _suppress;

  set suppress(bool value) {
    if (_suppress == value) return;
    _suppress = value;
    if (value) {
      _dismissAllVisible();
      return;
    }
    _scheduleFlush();
  }

  void show(
    String message, {
    ForjaToastKind kind = ForjaToastKind.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    String? tag,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    _queued.add(
      _QueuedToast(
        message: trimmed,
        kind: kind,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        tag: tag,
      ),
    );
    if (!_suppress) _scheduleFlush();
  }

  void dismiss(String id) {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length != before) notifyListeners();
  }

  void dismissTag(String tag) {
    if (tag.isEmpty) return;
    final before = _entries.length;
    _entries.removeWhere((e) => e.tag == tag);
    _queued.removeWhere((e) => e.tag == tag);
    if (_entries.length != before) notifyListeners();
  }

  void _dismissAllVisible() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  void _scheduleFlush() {
    if (_flushScheduled || _suppress || _queued.isEmpty) return;
    _flushScheduled = true;
    // Next frame — inserting IconButton / MouseRegion during a pointer
    // hit-test update trips mouse_tracker `!_debugDuringDeviceUpdate`.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_suppress || _queued.isEmpty) return;
      final batch = List<_QueuedToast>.of(_queued);
      _queued.clear();
      for (final item in batch) {
        _present(item);
      }
    });
  }

  void _present(_QueuedToast item) {
    if (item.tag != null) {
      _entries.removeWhere((e) => e.tag == item.tag);
    }
    _entries.add(
      ForjaToastEntry(
        id: 'toast_${++_seq}',
        message: item.message,
        kind: item.kind,
        duration: item.duration,
        actionLabel: item.actionLabel,
        onAction: item.onAction,
        tag: item.tag,
      ),
    );
    _trimEntries();
    notifyListeners();
  }

  void _trimEntries() {
    while (_entries.length > maxVisible) {
      // Prefer dropping oldest timed so sticky (duration zero) stay put.
      final timedIdx = _entries.indexWhere((e) => e.isTimed);
      _entries.removeAt(timedIdx >= 0 ? timedIdx : 0);
    }
  }

  @override
  void dispose() {
    _entries.clear();
    _queued.clear();
    super.dispose();
  }
}

class ForjaToastHost extends StatefulWidget {
  const ForjaToastHost({
    super.key,
    required this.child,
    this.allowDisplay,
    this.stackAbove = const [],
  });

  final Widget child;

  /// When false, toasts are queued (not painted). Defaults to always allow.
  final ValueListenable<bool>? allowDisplay;

  /// Progress banners etc. stacked above toast cards in the same column.
  /// Each child should return [SizedBox.shrink] when hidden.
  final List<Widget> stackAbove;

  @override
  State<ForjaToastHost> createState() => _ForjaToastHostState();
}

class _ForjaToastHostState extends State<ForjaToastHost> {
  @override
  void initState() {
    super.initState();
    widget.allowDisplay?.addListener(_syncSuppress);
    _syncSuppress();
  }

  @override
  void didUpdateWidget(covariant ForjaToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allowDisplay != widget.allowDisplay) {
      oldWidget.allowDisplay?.removeListener(_syncSuppress);
      widget.allowDisplay?.addListener(_syncSuppress);
      _syncSuppress();
    }
  }

  @override
  void dispose() {
    widget.allowDisplay?.removeListener(_syncSuppress);
    super.dispose();
  }

  void _syncSuppress() {
    final allow = widget.allowDisplay?.value ?? true;
    ForjaToast.controller.suppress = !allow;
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tv = policy.useFocusableMoodChips;
    final pointerHover = policy.scaleOnHover;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: ForjaToast.controller,
              builder: (context, _) {
                final entries = ForjaToast.controller.entries;
                if (entries.isEmpty && widget.stackAbove.isEmpty) {
                  return const SizedBox.shrink();
                }

                final cards = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...widget.stackAbove,
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ForjaToastCard(
                          key: ValueKey(entry.id),
                          entry: entry,
                          tvFocus: tv,
                          pointerHover: pointerHover,
                        ),
                      ),
                  ],
                );

                return SizedBox(
                  width: 360,
                  child: tv
                      ? FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: cards,
                        )
                      : cards,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ForjaToastCard extends StatefulWidget {
  const _ForjaToastCard({
    super.key,
    required this.entry,
    required this.tvFocus,
    required this.pointerHover,
  });

  final ForjaToastEntry entry;
  final bool tvFocus;

  /// Desktop hybrid — mouse hover pause + Material button overlays.
  /// Leanback TV has focus chips but not pointer hover.
  final bool pointerHover;

  @override
  State<_ForjaToastCard> createState() => _ForjaToastCardState();
}

class _ForjaToastCardState extends State<_ForjaToastCard>
    with SingleTickerProviderStateMixin {
  FocusNode? _actionFocus;
  FocusNode? _returnFocus;
  bool _stoleFocus = false;
  AnimationController? _progress;
  bool _hovered = false;

  bool get _hasAction => widget.entry.hasAction;

  bool get _tvActionFocus => widget.tvFocus && !widget.pointerHover && _hasAction;

  bool get _timed => widget.entry.isTimed;

  bool get _usePointerButtons => widget.pointerHover || !widget.tvFocus;

  @override
  void initState() {
    super.initState();
    _startProgress();
    if (!_tvActionFocus) return;
    // Capture before autofocus steals primary focus on the next frame.
    _returnFocus = FocusManager.instance.primaryFocus;
    _actionFocus = FocusNode(debugLabel: 'toast-action-${widget.entry.id}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _actionFocus;
      if (node == null || !node.canRequestFocus) return;
      node.requestFocus();
      _stoleFocus = true;
    });
  }

  void _startProgress() {
    _progress?.dispose();
    _progress = null;
    if (!_timed) return;
    final controller = AnimationController(
      vsync: this,
      duration: widget.entry.duration,
    );
    _progress = controller;
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (!mounted) return;
      ForjaToast.controller.dismiss(widget.entry.id);
    });
    if (!_hovered) {
      controller.forward();
    }
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    final progress = _progress;
    if (progress == null) return;
    if (hovered) {
      progress.stop();
    } else if (progress.status != AnimationStatus.completed) {
      progress.forward();
    }
  }

  @override
  void dispose() {
    _progress?.dispose();
    _progress = null;
    final heldFocus = _stoleFocus && (_actionFocus?.hasFocus ?? false);
    final back = _returnFocus;
    _returnFocus = null;
    _actionFocus?.dispose();
    _actionFocus = null;
    if (heldFocus && back != null) {
      // Toast gone while action still focused — land back on prior control.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (back.canRequestFocus) back.requestFocus();
      });
    }
    super.dispose();
  }

  /// D-pad / Back off the action: dismiss (close is not in the TV focus graph)
  /// and land on the control that owned focus before the toast stole it.
  void _leaveToastFocus() {
    final id = widget.entry.id;
    final back = _returnFocus;
    ForjaToast.controller.dismiss(id);
    if (back == null || !back.canRequestFocus) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (back.canRequestFocus) back.requestFocus();
    });
  }

  void _runActionSafe(VoidCallback? action, {required bool dismiss}) {
    final id = widget.entry.id;
    // Never mutate the overlay tree (dismiss / open dialogs) inside the
    // button's pointer-up — that trips mouse_tracker on desktop.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (dismiss) ForjaToast.controller.dismiss(id);
      if (action == null) return;
      SchedulerBinding.instance.addPostFrameCallback((_) => action());
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final style = forjaToastStyle(entry.kind);
    final progress = _progress;
    final hoverFill = ForjaShellColors.textPrimary.withValues(alpha: 0.10);
    final pressFill = ForjaShellColors.textPrimary.withValues(alpha: 0.16);

    WidgetStateProperty<Color?> buttonOverlay() =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return pressFill;
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverFill;
          }
          return Colors.transparent;
        });

    Widget actionButton() {
      final label = Text(
        entry.actionLabel!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: style.accent,
        ),
      );
      void onTap() => _runActionSafe(entry.onAction, dismiss: true);

      if (_usePointerButtons) {
        return TextButton(
          onPressed: onTap,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(style.accent),
            overlayColor: buttonOverlay(),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8),
            ),
            minimumSize: const WidgetStatePropertyAll(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: label,
        );
      }

      return shellFocusableTap(
        context: context,
        onTap: onTap,
        focusNode: _actionFocus,
        borderRadius: 6,
        showFocusBorder: true,
        scaleOnFocus: 1.0,
        // D-pad leave / Back → dismiss + prior control (close is not focusable).
        onLeftEdge: _leaveToastFocus,
        onRightEdge: _leaveToastFocus,
        onUpEdge: _leaveToastFocus,
        onDownEdge: _leaveToastFocus,
        onKeyEvent: (node, event) {
          if (!_isToastLeaveKey(event)) return KeyEventResult.ignored;
          _leaveToastFocus();
          return KeyEventResult.handled;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: label,
        ),
      );
    }

    Widget closeButton() {
      final icon = Icon(
        Icons.close_rounded,
        size: 16,
        color: ForjaShellColors.textSecondary.withValues(alpha: 0.8),
      );
      void onTap() => _runActionSafe(null, dismiss: true);

      if (_usePointerButtons) {
        return IconButton(
          onPressed: onTap,
          icon: icon,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(
              ForjaShellColors.textSecondary.withValues(alpha: 0.8),
            ),
            overlayColor: buttonOverlay(),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: const WidgetStatePropertyAll(Size(28, 28)),
            maximumSize: const WidgetStatePropertyAll(Size(28, 28)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        );
      }

      // Action toast already owns focus; keep close out of the D-pad graph.
      if (_hasAction) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ExcludeFocus(
            child: SizedBox(
              width: 28,
              height: 28,
              child: Center(child: icon),
            ),
          ),
        );
      }

      return shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: 14,
        showFocusBorder: true,
        scaleOnFocus: 1.0,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(child: icon),
        ),
      );
    }

    final card = ForjaToastChrome(
      kind: entry.kind,
      bottom: progress == null
          ? null
          : AnimatedBuilder(
              animation: progress,
              builder: (context, _) {
                return LinearProgressIndicator(
                  // Drain left → right (remaining time).
                  value: 1.0 - progress.value,
                  minHeight: 2,
                  backgroundColor: ForjaShellColors.borderSubtle
                      .withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    style.accent.withValues(alpha: 0.85),
                  ),
                );
              },
            ),
      child: Row(
        children: [
          Icon(
            style.icon,
            size: ShellPaintScope.iconOf(context, 18),
            color: style.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (_hasAction) ...[
            const SizedBox(width: 8),
            actionButton(),
          ],
          closeButton(),
        ],
      ),
    );

    // Desktop hybrid also has tv focus chips — do not gate MouseRegion on
    // tvFocus or pause never runs (same trap as liveLeanbackOnly vs liveUseTvFocus).
    if (!widget.pointerHover || progress == null) return card;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: card,
    );
  }
}

bool _isToastLeaveKey(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
  final key = event.logicalKey;
  return key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape;
}

/// Shared top-right card chrome — kind drives border / accent / fill.
class ForjaToastChrome extends StatelessWidget {
  const ForjaToastChrome({
    super.key,
    required this.kind,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 8, 10),
    this.bottom,
  });

  final ForjaToastKind kind;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final style = forjaToastStyle(kind);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: style.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: style.accent),
                    Expanded(
                      child: Padding(
                        padding: padding,
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }
}

class ForjaToastStyle {
  const ForjaToastStyle({
    required this.background,
    required this.border,
    required this.accent,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color accent;
  final IconData icon;
}

ForjaToastStyle forjaToastStyle(ForjaToastKind kind) {
  switch (kind) {
    case ForjaToastKind.success:
      return const ForjaToastStyle(
        background: Color(0xFF14261C),
        border: Color(0xFF1CE783),
        accent: ForjaShellColors.brandGreen,
        icon: Icons.check_circle_rounded,
      );
    case ForjaToastKind.error:
      return const ForjaToastStyle(
        background: Color(0xFF2A1416),
        border: Color(0xFFEF4444),
        accent: Color(0xFFF87171),
        icon: Icons.error_rounded,
      );
    case ForjaToastKind.warning:
      return const ForjaToastStyle(
        background: Color(0xFF2A2114),
        border: Color(0xFFF59E0B),
        accent: Color(0xFFFBBF24),
        icon: Icons.warning_amber_rounded,
      );
    case ForjaToastKind.info:
      return const ForjaToastStyle(
        background: Color(0xFF141C2A),
        border: Color(0xFF3B82F6),
        accent: Color(0xFF60A5FA),
        icon: Icons.info_rounded,
      );
  }
}
