import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja/shared/services/update/app_update_download_service.dart';

/// Sticky progress card for background desktop update downloads.
/// Place in [ForjaToastHost.stackAbove] — not a separate overlay.
class AppUpdateProgressBanner extends StatelessWidget {
  const AppUpdateProgressBanner({
    super.key,
    this.hideWhenPlayerActive,
  });

  /// When true, banner hides (player owns the surface). Bound from frame/bus.
  final ValueListenable<bool>? hideWhenPlayerActive;

  @override
  Widget build(BuildContext context) {
    final download = AppUpdateDownloadService.instance;
    final player = hideWhenPlayerActive;
    final listenable = player == null
        ? Listenable.merge([
            download.state,
            download.progressBannerDismissed,
          ])
        : Listenable.merge([
            download.state,
            download.progressBannerDismissed,
            player,
          ]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        if (player?.value == true) {
          return const SizedBox.shrink();
        }
        if (!download.shouldShowProgressBanner) {
          return const SizedBox.shrink();
        }
        final current = download.state.value;
        final version = current.updateInfo?.latestVersion;
        final percent = (current.progress * 100).clamp(0, 100).round();
        final tv = ShellPaintScope.usesTvDensityOf(context);
        final stackGap =
            ShellTokens.chromeScale(ShellTokens.toastStackGap, tv: tv);
        return Padding(
          padding: EdgeInsets.only(bottom: stackGap),
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final titleFont = tv
        ? ShellTokens.tvTypeSize(ShellTokens.toastMessageFontSize)
        : ShellTokens.toastMessageFontSize;
    final metaFont = tv
        ? ShellTokens.tvTypeSize(ShellTokens.toastActionFontSize)
        : ShellTokens.toastActionFontSize;
    final iconGap =
        ShellTokens.chromeScale(ShellTokens.toastMessageIconGap, tv: tv);
    final closeSize =
        ShellTokens.chromeScale(ShellTokens.toastCloseSize, tv: tv);
    final barGap = ShellTokens.chromeScale(ShellTokens.toastStackGap, tv: tv);
    final barH = ShellTokens.chromeScale(4, tv: tv);

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
                size: ShellPaintScope.iconOf(context, ShellTokens.toastIconSize),
                color: style.accent,
              ),
              SizedBox(width: iconGap),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: titleFont,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: style.accent,
                  fontSize: metaFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  size: ShellPaintScope.iconOf(
                    context,
                    ShellTokens.toastCloseIconSize,
                  ),
                  color: ForjaShellColors.textSecondary.withValues(
                    alpha: 0.8,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: closeSize,
                  minHeight: closeSize,
                ),
                splashRadius: closeSize / 2,
              ),
            ],
          ),
          SizedBox(height: barGap),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
              minHeight: barH,
              backgroundColor: ForjaShellColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(style.accent),
            ),
          ),
        ],
      ),
    );
  }
}
