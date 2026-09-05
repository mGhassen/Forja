import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

enum ForjaToastKind { success, error, warning, info }

class ForjaToastEntry {
  ForjaToastEntry({
    required this.id,
    required this.message,
    required this.kind,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  final String id;
  final String message;
  final ForjaToastKind kind;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _QueuedToast {
  const _QueuedToast({
    required this.message,
    required this.kind,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ForjaToastKind kind;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Top-right floating status toasts. Mount [ForjaToastHost] once at app root.
abstract final class ForjaToast {
  static final ForjaToastController controller = ForjaToastController();

  static void show(
    String message, {
    ForjaToastKind kind = ForjaToastKind.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    controller.show(
      message,
      kind: kind,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void success(
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        kind: ForjaToastKind.success,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void error(
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        kind: ForjaToastKind.error,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void warning(
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        kind: ForjaToastKind.warning,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void info(
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        kind: ForjaToastKind.info,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

class ForjaToastController extends ChangeNotifier {
  final List<ForjaToastEntry> _entries = [];
  final List<_QueuedToast> _queued = [];
  final Map<String, Timer> _timers = {};
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
      ),
    );
    if (!_suppress) _scheduleFlush();
  }

  void dismiss(String id) {
    _timers.remove(id)?.cancel();
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length != before) notifyListeners();
  }

  void _dismissAllVisible() {
    if (_entries.isEmpty && _timers.isEmpty) return;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    if (_entries.isNotEmpty) {
      _entries.clear();
      notifyListeners();
    }
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
    final id = 'toast_${++_seq}';
    final entry = ForjaToastEntry(
      id: id,
      message: item.message,
      kind: item.kind,
      duration: item.duration,
      actionLabel: item.actionLabel,
      onAction: item.onAction,
    );
    _entries.add(entry);
    if (_entries.length > 4) {
      dismiss(_entries.first.id);
    }
    notifyListeners();
    _timers[id] = Timer(item.duration, () => dismiss(id));
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
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
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

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
                        child: _ForjaToastCard(entry: entry, tvFocus: tv),
                      ),
                  ],
                );

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
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

class _ForjaToastCard extends StatelessWidget {
  const _ForjaToastCard({required this.entry, required this.tvFocus});

  final ForjaToastEntry entry;
  final bool tvFocus;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(entry.kind);

    void runActionSafe(VoidCallback? action, {required bool dismiss}) {
      final id = entry.id;
      // Never mutate the overlay tree (dismiss / open dialogs) inside the
      // button's pointer-up — that trips mouse_tracker on desktop.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (dismiss) ForjaToast.controller.dismiss(id);
        if (action == null) return;
        SchedulerBinding.instance.addPostFrameCallback((_) => action());
      });
    }

    Widget actionButton() {
      final label = Text(
        entry.actionLabel!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tvFocus ? ForjaShellColors.brandGreen : style.accent,
        ),
      );
      void onTap() => runActionSafe(entry.onAction, dismiss: true);

      if (!tvFocus) {
        return TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: style.accent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: label,
        );
      }

      return shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: 6,
        showFocusBorder: true,
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
      void onTap() => runActionSafe(null, dismiss: true);

      if (!tvFocus) {
        return IconButton(
          onPressed: onTap,
          icon: icon,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          splashRadius: 14,
        );
      }

      return shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: 14,
        showFocusBorder: true,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(child: icon),
        ),
      );
    }

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(style.icon, size: 18, color: style.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.message,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
              if (entry.actionLabel != null && entry.onAction != null) ...[
                const SizedBox(width: 8),
                actionButton(),
              ],
              closeButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastStyle {
  const _ToastStyle({
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

_ToastStyle _styleFor(ForjaToastKind kind) {
  switch (kind) {
    case ForjaToastKind.success:
      return const _ToastStyle(
        background: Color(0xFF14261C),
        border: Color(0xFF1CE783),
        accent: ForjaShellColors.brandGreen,
        icon: Icons.check_circle_rounded,
      );
    case ForjaToastKind.error:
      return const _ToastStyle(
        background: Color(0xFF2A1416),
        border: Color(0xFFEF4444),
        accent: Color(0xFFF87171),
        icon: Icons.error_rounded,
      );
    case ForjaToastKind.warning:
      return const _ToastStyle(
        background: Color(0xFF2A2114),
        border: Color(0xFFF59E0B),
        accent: Color(0xFFFBBF24),
        icon: Icons.warning_amber_rounded,
      );
    case ForjaToastKind.info:
      return const _ToastStyle(
        background: Color(0xFF1C1C1C),
        border: Color(0xFF4B5563),
        accent: Color(0xFF9CA3AF),
        icon: Icons.info_rounded,
      );
  }
}
