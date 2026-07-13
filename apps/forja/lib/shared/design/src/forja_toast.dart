import 'dart:async';

import 'package:flutter/material.dart';
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
  final Map<String, Timer> _timers = {};
  int _seq = 0;

  List<ForjaToastEntry> get entries => List.unmodifiable(_entries);

  void show(
    String message, {
    ForjaToastKind kind = ForjaToastKind.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final id = 'toast_${++_seq}';
    final entry = ForjaToastEntry(
      id: id,
      message: trimmed,
      kind: kind,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _entries.add(entry);
    if (_entries.length > 4) {
      dismiss(_entries.first.id);
    }
    notifyListeners();
    _timers[id] = Timer(duration, () => dismiss(id));
  }

  void dismiss(String id) {
    _timers.remove(id)?.cancel();
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length != before) notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _entries.clear();
    super.dispose();
  }
}

class ForjaToastHost extends StatelessWidget {
  const ForjaToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return Stack(
      children: [
        child,
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: ForjaToast.controller,
              builder: (context, _) {
                final entries = ForjaToast.controller.entries;
                if (entries.isEmpty) return const SizedBox.shrink();

                final cards = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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

    Widget actionButton() {
      final label = Text(
        entry.actionLabel!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tvFocus ? ForjaShellColors.brandGreen : style.accent,
        ),
      );
      void onTap() {
        entry.onAction!();
        ForjaToast.controller.dismiss(entry.id);
      }

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
      void onTap() => ForjaToast.controller.dismiss(entry.id);

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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 18, color: style.accent),
              const SizedBox(width: 10),
              Flexible(
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
