import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';

/// Inline download progress for Settings → Forja plugins (add / refresh).
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
    final title = progress.isUpdate ? 'Updating plugin…' : 'Installing plugin…';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  progress.isUpdate
                      ? Icons.system_update_alt_rounded
                      : Icons.download_rounded,
                  size: 16,
                  color: ForjaShellColors.brandGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: ForjaShellColors.brandGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (manifest != null && manifest.isNotEmpty) ...[
              const SizedBox(height: 4),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
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
            const SizedBox(height: 6),
            Text(
              'The plugin is usable when this bar reaches 100%.',
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
                  Icon(
                    active ? Icons.download_rounded : Icons.hourglass_top_rounded,
                    size: 18,
                    color: active
                        ? ForjaShellColors.brandGreen
                        : ForjaShellColors.textSecondary,
                  ),
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
                ],
              ),
              const SizedBox(height: 6),
              Text(
                active
                    ? (progress?.label ?? 'Downloading scripts…')
                    : 'Waiting for scripts — open Settings or wait for background install.',
                style: TextStyle(
                  fontSize: 11,
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              if (active && progress != null) ...[
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
