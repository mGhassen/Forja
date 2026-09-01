import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';

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

/// Pending pack row — manifest registered, scripts still downloading.
class SettingsEnginePackPendingTile extends StatelessWidget {
  const SettingsEnginePackPendingTile({
    super.key,
    required this.packName,
    required this.sourceUrl,
    this.progress,
  });

  final String packName;
  final String sourceUrl;
  final PluginInstallProgress? progress;

  @override
  Widget build(BuildContext context) {
    final active = progress?.matchesUrl(sourceUrl) == true;
    final phase = active ? progress!.phase : PluginInstallPhase.loading;
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
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                      ],
                    ),
                  ),
                  Text(
                    active ? progress!.phaseTitle : 'Waiting',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? ForjaShellColors.brandGreen
                          : ForjaShellColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                active
                    ? (progress?.label ?? 'Downloading scripts…')
                    : 'Queued — install continues in the background.',
                style: TextStyle(
                  fontSize: 11,
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              if (active && progress != null && progress!.phase != PluginInstallPhase.ready) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress!.totalSteps > 0 ? progress!.fraction : null,
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
        ),
      ),
    );
  }
}

/// Ready / installing chip on an installed pack row.
class SettingsEnginePackInstallStatus extends StatelessWidget {
  const SettingsEnginePackInstallStatus({
    super.key,
    required this.sourceUrl,
    this.progress,
  });

  final String sourceUrl;
  final PluginInstallProgress? progress;

  @override
  Widget build(BuildContext context) {
    if (progress != null && progress!.matchesUrl(sourceUrl)) {
      return Text(
        '${progress!.phaseTitle} · ${progress!.label}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: ForjaShellColors.brandGreen,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text(
      'Ready',
      style: TextStyle(
        fontSize: 11,
        color: ForjaShellColors.textSecondary.withValues(alpha: 0.75),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
