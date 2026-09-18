import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/nav/pack_update_alert_icon.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Shared copy for pack-update chrome (Settings bar, nav flyout, toast).
abstract final class EnginePackUpdateCopy {
  static String available(int count) {
    if (count <= 0) return upToDate;
    if (count == 1) return '1 update available';
    return '$count updates available';
  }

  static const menuBadge = 'Update available';
  static const checking = 'Checking for plugin updates…';
  static const upToDate = 'All plugins are up to date';
}

/// Yellow “Update available” chip for Settings → Forja Packs row.
class PackUpdateMenuBadge extends StatelessWidget {
  const PackUpdateMenuBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ShellTokens.packUpdateMenuBadgePadH,
        vertical: ShellTokens.packUpdateMenuBadgePadV,
      ),
      decoration: BoxDecoration(
        color: ForjaShellColors.packUpdateAlert.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(
          ShellTokens.packUpdateMenuBadgeRadius,
        ),
        border: Border.all(
          color: ForjaShellColors.packUpdateAlert.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        EnginePackUpdateCopy.menuBadge,
        style: TextStyle(
          fontSize: ShellTokens.packUpdateMenuBadgeFontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: ForjaShellColors.packUpdateAlert,
        ),
      ),
    );
  }
}

/// Shared sun glyph for pack-update chrome (nav badge + Settings tile).
abstract final class PackUpdateAlertGlyph {
  static const IconData icon = Icons.wb_sunny_rounded;
}

/// Pack toolbar: optional update status on the left, actions on the right.
class SettingsEnginePackUpdatesBar extends StatelessWidget {
  const SettingsEnginePackUpdatesBar({
    super.key,
    required this.updateCount,
    required this.checking,
    required this.onUpdateAll,
    required this.onCheckAgain,
    this.updating = false,
    this.actions = const [],
  });

  final int updateCount;
  final bool checking;
  final bool updating;
  final VoidCallback onUpdateAll;
  final VoidCallback onCheckAgain;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final hasUpdates = updateCount > 0;
    final showStatus = hasUpdates || checking;
    if (!showStatus && actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (showStatus) ...[
            if (hasUpdates)
              const PackUpdateAlertIcon(
                size: ShellTokens.packUpdateFlyoutIconSize,
                heartbeat: false,
              )
            else
              const Icon(
                Icons.sync_rounded,
                size: ShellTokens.packUpdateFlyoutIconSize,
                color: ForjaShellColors.textSecondary,
              ),
            const SizedBox(width: ShellTokens.packUpdateFlyoutGap),
            Expanded(
              child: Text(
                checking
                    ? EnginePackUpdateCopy.checking
                    : hasUpdates
                    ? EnginePackUpdateCopy.available(updateCount)
                    : EnginePackUpdateCopy.upToDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasUpdates
                      ? ForjaShellColors.packUpdateAlert
                      : ForjaShellColors.textSecondary,
                ),
              ),
            ),
          ] else
            const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            actions[i],
          ],
          if (checking) ...[
            if (actions.isNotEmpty) const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else if (hasUpdates) ...[
            if (actions.isNotEmpty) const SizedBox(width: 12),
            Button(
              label: updating ? 'Updating…' : 'Update all',
              icon: Icons.download_rounded,
              variant: ButtonVariant.primary,
              height: 36,
              loading: updating,
              onPressed: updating ? null : onUpdateAll,
            ),
          ] else if (showStatus) ...[
            if (actions.isNotEmpty) const SizedBox(width: 12),
            SettingsTextAction(
              label: 'Check again',
              onPressed: onCheckAgain,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pack name + optional deprecated tag when the manifest URL is gone.
class SettingsEnginePackTitle extends StatelessWidget {
  const SettingsEnginePackTitle({
    super.key,
    required this.name,
    this.deprecated = false,
  });

  final String name;
  final bool deprecated;

  static const _deprecatedRed = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: deprecated
                  ? _deprecatedRed
                  : ForjaShellColors.textPrimary,
            ),
          ),
        ),
        if (deprecated) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _deprecatedRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _deprecatedRed.withValues(alpha: 0.45),
              ),
            ),
            child: const Text(
              'deprecated',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: _deprecatedRed,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Version line under each installed pack row.
class SettingsEnginePackVersionLine extends StatelessWidget {
  const SettingsEnginePackVersionLine({
    super.key,
    required this.meta,
  });

  final String meta;

  @override
  Widget build(BuildContext context) {
    return Text(
      meta,
      style: TextStyle(
        fontSize: 11,
        color: ForjaShellColors.textSecondary.withValues(alpha: 0.75),
      ),
    );
  }
}
