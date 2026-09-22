import 'package:flutter/material.dart';
import 'package:forja/shell/feedback/forja_toast.dart';

import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Sticky progress card while Engine/Nuvio packs download or update.
/// Place in [ForjaToastHost.stackAbove] — stacks above timed toast cards.
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
        final tv = ShellPaintScope.usesTvDensityOf(context);
        final stackGap =
            ShellTokens.chromeScale(ShellTokens.toastStackGap, tv: tv);
        return ExcludeFocus(
          child: Padding(
            padding: EdgeInsets.only(bottom: stackGap),
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
    // Always info chrome — green success belongs to stacked [ForjaToast] cards.
    // Flipping this card green on fraction==1 then blue on the next pack looked
    // like one toast thrashing colors during Reload all.
    const kind = ForjaToastKind.info;
    final style = forjaToastStyle(kind);
    final percent = (progress.fraction * 100).clamp(0, 100).round();
    final title = progress.isUpdate
        ? 'Updating plugins…'
        : 'Downloading plugins…';
    final icon = progress.isUpdate
        ? Icons.system_update_alt_rounded
        : Icons.download_rounded;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final iconGap =
        ShellTokens.chromeScale(ShellTokens.toastMessageIconGap, tv: tv);
    final lineGap = ShellTokens.chromeScale(2, tv: tv);
    final barGap = ShellTokens.chromeScale(ShellTokens.toastStackGap, tv: tv);
    final barH = ShellTokens.chromeScale(4, tv: tv);

    return ForjaToastChrome(
      kind: kind,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: SettingsTokens.filledButtonIconSizeOf(context),
                color: style.accent,
              ),
              SizedBox(width: iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: SettingsTokens.rowTitleSizeOf(context),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: lineGap),
                    Text(
                      progress.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: SettingsTokens.groupLabelSizeOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (progress.manifestUrl != null &&
                        progress.manifestUrl!.trim().isNotEmpty) ...[
                      SizedBox(height: lineGap),
                      Text(
                        progress.manifestUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary
                              .withValues(alpha: 0.75),
                          fontSize: SettingsTokens.groupLabelSizeOf(context),
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
                  fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: barGap),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.totalSteps > 0 ? progress.fraction : null,
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
