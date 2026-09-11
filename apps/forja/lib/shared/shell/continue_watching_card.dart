import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/shell/shell_card_play_overlay.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/widgets/catalog/continue_section.dart';
import 'package:forja_foundation/widgets/catalog/continue_watching_card.dart';

export 'package:forja_foundation/widgets/catalog/continue_watching_card.dart'
    show ContinueWatchingCard;
export 'package:forja_foundation/widgets/catalog/continue_section.dart'
    show ContinueEntry;

/// Host TV/focus wrapper around DS [ContinueWatchingCard].
class HostContinueWatchingCard extends StatefulWidget {
  const HostContinueWatchingCard({
    super.key,
    required this.tabId,
    required this.entry,
    required this.onTap,
    required this.onRemove,
    required this.onInfo,
    required this.listIndex,
    this.isLoading = false,
  });

  final String tabId;
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final int listIndex;
  final bool isLoading;

  static double cardWidth(BuildContext context) =>
      shellContinueWatchingCardWidth(context);

  static double cardHeight(BuildContext context) =>
      shellContinueWatchingCardHeight(context);

  @override
  State<HostContinueWatchingCard> createState() =>
      _HostContinueWatchingCardState();
}

class _HostContinueWatchingCardState extends State<HostContinueWatchingCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _activeFor(ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hovered,
        focused: _focused,
        context: context,
      );

  Future<void> _showTvActions(BuildContext context) async {
    final mapped = ContinueEntry.fromMap(widget.entry);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          title: Text(
            mapped.title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              shellFocusableTap(
                context: ctx,
                borderRadius: 8,
                onTap: () => Navigator.pop(ctx, 'info'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'More info',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
              shellFocusableTap(
                context: ctx,
                borderRadius: 8,
                onTap: () => Navigator.pop(ctx, 'remove'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Remove from Continue Watching',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'info':
        widget.onInfo();
      case 'remove':
        widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final mapped = ContinueEntry.fromMap(widget.entry);
    final radius = shellCardBorderRadius(context);
    final active = _activeFor(policy);

    return shellFocusableTap(
      context: context,
      onTap: widget.isLoading ? null : widget.onTap,
      listIndex: widget.listIndex,
      tvTabId: widget.tabId,
      tvRowId: 'continue-watching',
      tvItemIndex: widget.listIndex,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      onKeyEvent: policy.useFocusableMoodChips
          ? (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.contextMenu ||
                  key == LogicalKeyboardKey.f1) {
                unawaited(_showTvActions(context));
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: ContinueWatchingCard(
        title: mapped.title,
        coverUrl: mapped.coverUrl,
        subtitle: mapped.subtitle,
        progress: mapped.progress,
        remainingText: mapped.remainingText,
        width: HostContinueWatchingCard.cardWidth(context),
        height: HostContinueWatchingCard.cardHeight(context),
        borderRadius: radius,
        active: active,
        isLoading: widget.isLoading,
        showActionButtons: policy.scaleOnHover,
        onRemove: widget.onRemove,
        onInfo: widget.onInfo,
        playOverlay: ShellCardPlayOverlay(
          active: false,
          visible: active && !widget.isLoading,
        ),
      ),
    );
  }
}

/// Legacy name — prefer [HostContinueWatchingCard].
typedef ContinueWatchingCardHost = HostContinueWatchingCard;
