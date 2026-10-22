import 'package:flutter/material.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/card_quick_menu_tokens.dart';
import 'package:forja_foundation/widgets/catalog/card_quick_menu.dart';

/// Shell overlay for the catalog card quick menu (OK-hold / MENU on a card).
///
/// Generic chassis wire: takes the actions the caller already resolved for
/// the card, paints [CardQuickMenu] beside the focused card, traps D-pad
/// inside ([TvOverlayScope]), and restores focus to the card on close. Knows
/// nothing about packs or what the actions do.
///
/// One menu at a time — opening a second one closes the first.
abstract final class ShellTvCardQuickMenu {
  static OverlayEntry? _entry;
  static FocusNode? _returnFocus;
  static String _returnTabId = '';

  static bool get isOpen => _entry != null;

  /// Open for the card under [context].
  ///
  /// [anchor] is the card rect in global coordinates; when null the current
  /// primary focus (the held card on TV) is measured. Empty [actions] → no-op.
  static void show(
    BuildContext context, {
    required List<CardQuickMenuAction> actions,
    String? title,
    Rect? anchor,
  }) {
    if (actions.isEmpty) return;
    if (_entry != null) close(restoreFocus: false);

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // Capture everything at open time — the card context may be gone by the
    // time a toast or list change rebuilds the overlay.
    final shell = ShellScope.of(context);
    final policy = shell.inputPolicy;
    final tv = shell.metrics.usesTvDensity;
    final returnFocus = FocusManager.instance.primaryFocus;
    final rect = anchor ?? _focusedRect(returnFocus) ?? _fallbackRect(context);
    _returnFocus = returnFocus;
    _returnTabId = ShellTvFocus.currentNavTabId ?? '';

    final rows = <CardQuickMenuAction>[
      for (final a in actions)
        CardQuickMenuAction(
          id: a.id,
          label: a.label,
          icon: a.icon,
          onTap: () => _run(a.onTap),
        ),
    ];

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return ShellScope(
          profile: shell.profile,
          config: shell.config,
          child: TvOverlayScope(
            enabled: policy.useFocusableMoodChips,
            linear: true,
            onDismiss: close,
            debugLabel: 'card-quick-menu',
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: close,
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: CardQuickMenuTokens.scrimAlpha,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: CardQuickMenuLayoutDelegate(anchor: rect, tv: tv),
                    child: Material(
                      color: Colors.transparent,
                      child: CardQuickMenu(
                        title: title,
                        actions: rows,
                        tvFocus: policy.useFocusableMoodChips,
                        autoFocusFirst: policy.leanbackOnly,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
    if (policy.useFocusableMoodChips) {
      // HardwareKeyboard steals goBack before Focus onKey — Back must close
      // the menu first, not pop the page.
      ShellTvFocusCoordinator.setTransientOverlayDismiss(() {
        if (_entry == null) return false;
        close();
        return true;
      });
    }
  }

  /// Close the menu. Default restores focus to the card it opened from so
  /// Back / an action lands the user where they were.
  static bool close({bool restoreFocus = true}) {
    final entry = _entry;
    if (entry == null) return false;
    _entry = null;
    ShellTvFocusCoordinator.setTransientOverlayDismiss(null);
    entry.remove();
    final back = _returnFocus;
    final tabId = _returnTabId;
    _returnFocus = null;
    _returnTabId = '';
    if (!restoreFocus) return true;
    _refocus(back, tabId);
    return true;
  }

  /// Run an action: hand focus back to the card **before** the action so a
  /// route it pushes captures the card (not a disposed menu row) as the
  /// return focus.
  static void _run(VoidCallback action) {
    close();
    action();
  }

  static bool _alive(FocusNode? node) =>
      node != null && node.context != null && node.canRequestFocus;

  /// Card node first; when the card was rebuilt away (row reload while the
  /// menu was up) fall back to the tab's remembered focus.
  static void _refocus(FocusNode? back, String tabId) {
    if (_alive(back)) {
      back!.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
    } else if (tabId.isNotEmpty) {
      ShellTvFocusCoordinator.restoreTabFocus(tabId);
    }
    // Overlay teardown can re-claim focus this frame; settle after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entry != null) return;
      if (_alive(back)) {
        if (!back!.hasFocus) back.requestFocus();
        return;
      }
      if (tabId.isNotEmpty) ShellTvFocusCoordinator.restoreTabFocus(tabId);
    });
  }

  static Rect? _focusedRect(FocusNode? node) {
    final ctx = node?.context;
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  /// No measurable card — centre a zero-size anchor so the delegate centres
  /// the menu on screen.
  static Rect _fallbackRect(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 0,
      height: 0,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _entry?.remove();
    _entry = null;
    _returnFocus = null;
    _returnTabId = '';
    ShellTvFocusCoordinator.setTransientOverlayDismiss(null);
  }
}
