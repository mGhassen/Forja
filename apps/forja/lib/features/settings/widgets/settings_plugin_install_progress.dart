import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';

class _PhaseIcon extends StatelessWidget {
  const _PhaseIcon({required this.phase});

  final PluginInstallPhase phase;

  @override
  Widget build(BuildContext context) {
    final icon = switch (phase) {
      PluginInstallPhase.loading => Icons.hourglass_top_rounded,
      PluginInstallPhase.installing => Icons.download_rounded,
      PluginInstallPhase.ready => Icons.check_circle_rounded,
    };
    return Icon(icon, size: 16, color: ForjaShellColors.brandGreen);
  }
}

/// Pending pack row — lean stub, deferred install, or pending purge.
///
/// Compact like installed pack rows: status + download/uninstall icon on the
/// right — no full-width CTA row. Pending downloads also get a trash control
/// (Yes/No confirm) so unreachable / stale stubs can be removed on TV.
class SettingsEnginePackPendingTile extends StatefulWidget {
  const SettingsEnginePackPendingTile({
    super.key,
    required this.packName,
    required this.sourceUrl,
    this.progress,
    this.badge,
    this.actionTooltip,
    this.actionIcon = Icons.download_rounded,
    this.onAction,
    this.onRemove,
  });

  final String packName;
  final String sourceUrl;
  final PluginInstallProgress? progress;
  final String? badge;
  final String? actionTooltip;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final Future<void> Function()? onRemove;

  @override
  State<SettingsEnginePackPendingTile> createState() =>
      _SettingsEnginePackPendingTileState();
}

class _SettingsEnginePackPendingTileState
    extends State<SettingsEnginePackPendingTile> {
  bool _confirmingRemove = false;

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final sourceUrl = widget.sourceUrl;
    final activeProgress =
        progress != null && progress.matchesUrl(sourceUrl) ? progress : null;
    final phase = activeProgress?.phase ?? PluginInstallPhase.loading;
    final status = activeProgress != null
        ? (activeProgress.phase == PluginInstallPhase.ready
              ? 'Ready'
              : activeProgress.phaseTitle)
        : (widget.badge ?? 'Waiting');
    final detail = activeProgress?.label;
    // Flat row — same chrome as installed ExpansionTile headers (no card).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _PhaseIcon(phase: phase),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.packName,
                      style: const TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sourceUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ForjaShellColors.textSecondary,
                      ),
                    ),
                    if (detail != null &&
                        detail.toLowerCase() != status.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ForjaShellColors.brandGreen.withValues(
                            alpha: 0.95,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: activeProgress != null
                      ? ForjaShellColors.brandGreen
                      : ForjaShellColors.textSecondary,
                ),
              ),
              if (activeProgress == null) ...[
                if (widget.onAction != null && !_confirmingRemove) ...[
                  const SizedBox(width: 8),
                  _PendingActionIcon(
                    tooltip: widget.actionTooltip ?? 'Download',
                    icon: widget.actionIcon,
                    onPressed: widget.onAction!,
                    color: widget.actionIcon == Icons.delete_outline
                        ? const Color(0xFFF87171)
                        : ForjaShellColors.brandGreen,
                  ),
                ],
                if (widget.onRemove != null) ...[
                  const SizedBox(width: 4),
                  if (_confirmingRemove) ...[
                    _PendingActionIcon(
                      tooltip: 'Yes',
                      icon: Icons.check_rounded,
                      color: const Color(0xFFEF4444),
                      onPressed: () {
                        setState(() => _confirmingRemove = false);
                        unawaited(widget.onRemove!());
                      },
                    ),
                    _PendingActionIcon(
                      tooltip: 'No',
                      icon: Icons.close_rounded,
                      color: ForjaShellColors.iconMuted,
                      onPressed: () =>
                          setState(() => _confirmingRemove = false),
                    ),
                  ] else
                    _PendingActionIcon(
                      tooltip: 'Remove pack',
                      icon: Icons.delete_outline,
                      color: const Color(0xFFF87171),
                      onPressed: () =>
                          setState(() => _confirmingRemove = true),
                    ),
                ],
              ],
            ],
          ),
          if (activeProgress != null &&
              activeProgress.phase != PluginInstallPhase.ready) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: activeProgress.totalSteps > 0
                    ? activeProgress.fraction
                    : null,
                minHeight: 3,
                backgroundColor: ForjaShellColors.borderSubtle,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ForjaShellColors.brandGreen,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingActionIcon extends StatelessWidget {
  const _PendingActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, color: color, size: 20);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (tv) {
      return shellFocusableTap(
        context: context,
        onTap: onPressed,
        borderRadius: 8,
        scaleOnFocus: 1.0,
        showFocusRail: false,
        showFocusFill: true,
        showFocusBorder: true,
        tvTabId: 'settings',
        tvZone: ShellTvZone.settings,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      );
    }
    return IconButton(tooltip: tooltip, onPressed: onPressed, icon: child);
  }
}

/// Ready / installing chip on an installed pack row.
class SettingsEnginePackInstallStatus extends StatelessWidget {
  const SettingsEnginePackInstallStatus({
    super.key,
    required this.sourceUrl,
    this.progress,
    this.update,
  });

  final String sourceUrl;
  final PluginInstallProgress? progress;
  final EnginePackUpdateInfo? update;

  @override
  Widget build(BuildContext context) {
    if (progress != null && progress!.matchesUrl(sourceUrl)) {
      if (progress!.phase == PluginInstallPhase.ready) {
        return const SizedBox.shrink();
      }
      final title = progress!.phaseTitle;
      final label = progress!.label;
      final line = label.toLowerCase().startsWith(title.toLowerCase())
          ? label
          : '$title · $label';
      return Text(
        line,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: ForjaShellColors.brandGreen,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (update != null) {
      return Text(
        'Update available: v${update!.remoteVersion}',
        style: const TextStyle(
          fontSize: 11,
          color: ForjaShellColors.brandGreen,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
