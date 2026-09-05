import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shell/shell_bus.dart';

/// Sticky progress card while Engine/Nuvio packs download or update.
/// Place in [ForjaToastHost.stackAbove] — not a separate overlay.
class PluginInstallProgressBanner extends StatelessWidget {
  const PluginInstallProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final coordinator = PluginInstallCoordinator.instance;
    final listenable = Listenable.merge([
      coordinator.progress,
      coordinator.suppressBanner,
      ShellBus.playerSurfaceActive,
      ShellBus.splashDismissed,
    ]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        // Intro splash + profile warm use the splash status line.
        if (coordinator.suppressBanner.value ||
            !ShellBus.splashDismissed.value ||
            ShellBus.playerSurfaceActive.value) {
          return const SizedBox.shrink();
        }
        final current = coordinator.progress.value;
        if (current == null) return const SizedBox.shrink();
        return ExcludeFocus(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PluginInstallBanner(progress: current),
          ),
        );
      },
    );
  }
}

class _PluginInstallBanner extends StatelessWidget {
  const _PluginInstallBanner({required this.progress});

  final PluginInstallProgress progress;

  @override
  Widget build(BuildContext context) {
    final ready = progress.phase == PluginInstallPhase.ready;
    final kind = ready ? ForjaToastKind.success : ForjaToastKind.info;
    final style = forjaToastStyle(kind);
    final percent = (progress.fraction * 100).clamp(0, 100).round();
    final title = ready
        ? 'Plugins ready'
        : progress.isUpdate
            ? 'Updating plugins…'
            : 'Downloading plugins…';
    final icon = ready
        ? Icons.check_circle_rounded
        : progress.isUpdate
            ? Icons.system_update_alt_rounded
            : Icons.download_rounded;

    return ForjaToastChrome(
      kind: kind,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: style.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (progress.manifestUrl != null &&
                        progress.manifestUrl!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        progress.manifestUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary
                              .withValues(alpha: 0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: style.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.totalSteps > 0 ? progress.fraction : null,
              minHeight: 4,
              backgroundColor: ForjaShellColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(style.accent),
            ),
          ),
          if (ready) ...[
            const SizedBox(height: 6),
            Text(
              'Plugin is ready to use.',
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.85),
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
