import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';

/// Inline download progress for Settings → Forja plugins (add / refresh / boot).
class SettingsPluginInstallProgress extends StatelessWidget {
  const SettingsPluginInstallProgress({
    super.key,
    required this.progress,
  });

  final PluginInstallProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.fraction * 100).clamp(0, 100).round();
    final manifest = progress.manifestUrl?.trim();
    final phase = progress.phase;
    final phaseColor = phase == PluginInstallPhase.ready
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: phase == PluginInstallPhase.ready
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.5)
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
                const SizedBox(width: 8),
                Text(
                  progress.phaseTitle.toUpperCase(),
                  style: TextStyle(
                    color: phaseColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Text(
                  phase == PluginInstallPhase.ready ? '100%' : '$percent%',
                  style: TextStyle(
                    color: ForjaShellColors.brandGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (manifest != null && manifest.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                manifest,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              progress.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (phase != PluginInstallPhase.ready) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.totalSteps > 0 ? progress.fraction : null,
                  minHeight: 4,
                  backgroundColor: ForjaShellColors.borderSubtle,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ForjaShellColors.brandGreen,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              phase == PluginInstallPhase.ready
                  ? 'Plugin is ready to use.'
                  : 'Do not close the app — the plugin becomes usable at 100%.',
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.75),
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
