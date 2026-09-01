import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shell/shell_bus.dart';

/// Bottom-center progress toast while Engine/Nuvio packs download or update.
/// Hidden while any fullscreen video player surface is active.
class PluginInstallProgressBannerHost extends StatelessWidget {
  const PluginInstallProgressBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final coordinator = PluginInstallCoordinator.instance;
    final listenable = Listenable.merge([
      coordinator.progress,
      coordinator.suppressBanner,
      ShellBus.playerSurfaceActive,
      ShellBus.splashDismissed,
    ]);

    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: listenable,
              builder: (context, _) {
                // Intro splash + profile warm use the bottom status line.
                if (coordinator.suppressBanner.value ||
                    !ShellBus.splashDismissed.value ||
                    ShellBus.playerSurfaceActive.value) {
                  return const SizedBox.shrink();
                }
                final current = coordinator.progress.value;
                if (current == null) return const SizedBox.shrink();
                return ExcludeFocus(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _PluginInstallBanner(progress: current),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PluginInstallBanner extends StatelessWidget {
  const _PluginInstallBanner({required this.progress});

  final PluginInstallProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.fraction * 100).clamp(0, 100).round();
    final title = progress.isUpdate
        ? 'Updating plugins…'
        : 'Downloading plugins…';

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF14261C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1CE783)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    progress.isUpdate
                        ? Icons.system_update_alt_rounded
                        : Icons.download_rounded,
                    size: 18,
                    color: ForjaShellColors.brandGreen,
                  ),
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
                    style: const TextStyle(
                      color: ForjaShellColors.brandGreen,
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
                  value: progress.totalSteps > 0
                      ? progress.fraction
                      : null,
                  minHeight: 4,
                  backgroundColor: ForjaShellColors.borderSubtle,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ForjaShellColors.brandGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
