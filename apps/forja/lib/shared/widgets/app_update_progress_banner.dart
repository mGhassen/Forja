import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_update_download_service.dart';
import 'package:forja/shell/shell_bus.dart';

/// Sticky progress card for background desktop update downloads.
/// Place in [ForjaToastHost.stackAbove] — not a separate overlay.
class AppUpdateProgressBanner extends StatelessWidget {
  const AppUpdateProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final download = AppUpdateDownloadService.instance;
    final listenable = Listenable.merge([
      download.state,
      download.progressBannerDismissed,
      ShellBus.playerSurfaceActive,
    ]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        if (ShellBus.playerSurfaceActive.value) {
          return const SizedBox.shrink();
        }
        if (!download.shouldShowProgressBanner) {
          return const SizedBox.shrink();
        }
        final current = download.state.value;
        final version = current.updateInfo?.latestVersion;
        final percent = (current.progress * 100).clamp(0, 100).round();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _UpdateProgressBanner(
            version: version,
            percent: percent,
            progress: current.progress,
            onClose: download.dismissProgressBanner,
          ),
        );
      },
    );
  }
}

class _UpdateProgressBanner extends StatelessWidget {
  const _UpdateProgressBanner({
    required this.version,
    required this.percent,
    required this.progress,
    required this.onClose,
  });

  final String? version;
  final int percent;
  final double progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final style = forjaToastStyle(ForjaToastKind.info);
    final title = version == null
        ? 'Downloading update…'
        : 'Downloading Forja $version…';

    return ForjaToastChrome(
      kind: ForjaToastKind.info,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 18,
                color: style.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
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
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ForjaShellColors.textSecondary.withValues(
                    alpha: 0.8,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                splashRadius: 14,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
              minHeight: 4,
              backgroundColor: ForjaShellColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(style.accent),
            ),
          ),
        ],
      ),
    );
  }
}
