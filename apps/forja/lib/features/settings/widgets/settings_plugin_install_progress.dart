import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

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
/// right — no full-width CTA row.
class SettingsEnginePackPendingTile extends StatelessWidget {
  const SettingsEnginePackPendingTile({
    super.key,
    required this.packName,
    required this.sourceUrl,
    this.progress,
    this.badge,
    this.actionTooltip,
    this.actionIcon = Icons.download_rounded,
    this.onAction,
  });

  final String packName;
  final String sourceUrl;
  final PluginInstallProgress? progress;
  final String? badge;
  final String? actionTooltip;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final active = progress?.matchesUrl(sourceUrl) == true;
    final phase = active ? progress!.phase : PluginInstallPhase.loading;
    final status = active
        ? (progress!.phase == PluginInstallPhase.ready
            ? 'Ready'
            : progress!.phaseTitle)
        : (badge ?? 'Waiting');
    final detail = active
        ? progress!.label
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ForjaShellColors.surfaceElevated.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? ForjaShellColors.brandGreen.withValues(alpha: 0.45)
                : ForjaShellColors.borderSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                          packName,
                          style: const TextStyle(
                            color: ForjaShellColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sourceUrl,
                          maxLines: 2,
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
                              color: ForjaShellColors.brandGreen
                                  .withValues(alpha: 0.95),
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
                      color: active
                          ? ForjaShellColors.brandGreen
                          : ForjaShellColors.textSecondary,
                    ),
                  ),
                  if (onAction != null && !active)
                    _PendingActionIcon(
                      tooltip: actionTooltip ?? 'Download',
                      icon: actionIcon,
                      onPressed: onAction!,
                      color: actionIcon == Icons.delete_outline
                          ? const Color(0xFFF87171)
                          : ForjaShellColors.brandGreen,
                    ),
                ],
              ),
              if (active &&
                  progress != null &&
                  progress!.phase != PluginInstallPhase.ready) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value:
                          progress!.totalSteps > 0 ? progress!.fraction : null,
                      minHeight: 3,
                      backgroundColor: ForjaShellColors.borderSubtle,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        ForjaShellColors.brandGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
        showFocusRail: true,
        tvTabId: 'settings',
        tvZone: ShellTvZone.settings,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: child,
    );
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
