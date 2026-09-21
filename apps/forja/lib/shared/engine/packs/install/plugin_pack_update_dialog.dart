import 'package:flutter/material.dart';

import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Confirm overlay listing plugin packs with pending version bumps.
class PluginPackUpdateOverlay extends StatelessWidget {
  const PluginPackUpdateOverlay({
    super.key,
    required this.updates,
    required this.onDismiss,
  });

  final List<EnginePackUpdateInfo> updates;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TvOverlayScope(
      debugLabel: 'plugin-pack-update',
      // Body owns Update-all focus with retries (shell reclaim after openSettings).
      autofocusFirst: false,
      onDismiss: onDismiss,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.62),
              onDismiss: onDismiss,
            ),
            Center(
              child: _PluginPackUpdateBody(
                updates: updates,
                onCancel: onDismiss,
                onDone: onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginPackUpdateBody extends StatefulWidget {
  const _PluginPackUpdateBody({
    required this.updates,
    required this.onCancel,
    required this.onDone,
  });

  final List<EnginePackUpdateInfo> updates;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_PluginPackUpdateBody> createState() => _PluginPackUpdateBodyState();
}

class _PluginPackUpdateBodyState extends State<_PluginPackUpdateBody> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'plugin-update-cancel');
  final FocusNode _confirmFocus =
      FocusNode(debugLabel: 'plugin-update-confirm');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Stacked over the shell (and after openSettings) — claim Update all so
    // ATV D-pad cannot stay on the poster underneath (same class as I173).
    _claimPrimaryFocus();
  }

  void _claimPrimaryFocus({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_tvFocusActive(context)) return;
      if (_confirmFocus.canRequestFocus) {
        _confirmFocus.requestFocus();
        if (_confirmFocus.hasPrimaryFocus) return;
      }
      if (attempt < 4) _claimPrimaryFocus(attempt: attempt + 1);
    });
  }

  static bool _tvFocusActive(BuildContext context) {
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    return policy?.useFocusableMoodChips ??
        resolveShellProfile(context) == ShellProfile.tv;
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || widget.updates.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ok = await PluginInstallCoordinator.instance.updatePacks(
        widget.updates,
      );
      if (!mounted) return;
      if (ok > 0) {
        ForjaToast.success(
          ok == 1 ? '1 plugin pack updated' : '$ok plugin packs updated',
        );
      }
      widget.onDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.updates.length;
    final title = count == 1
        ? 'Update plugin pack?'
        : 'Update $count plugin packs?';
    final tv = _tvFocusActive(context) ||
        ShellPaintScope.usesTvDensityOf(context);
    final maxW = SettingsTokens.dialogMaxWidthOf(
      context,
      MediaQuery.sizeOf(context).width,
    );
    final radius = SettingsTokens.dialogRadiusOf(context);
    final pad = tv
        ? const EdgeInsets.fromLTRB(14, 12, 14, 10)
        : const EdgeInsets.fromLTRB(20, 18, 20, 16);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Material(
        color: ForjaShellColors.cinematic.menuSurface,
        elevation: 12,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: ForjaShellColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: pad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: tv ? ShellTokens.tvTitleFontSize : 18,
                ),
              ),
              SizedBox(height: tv ? 6 : 10),
              Text(
                count == 1
                    ? 'Download and install the newer version of this pack.'
                    : 'Download and install newer versions of these packs.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: tv ? ShellTokens.tvBodyFontSize : null,
                  height: 1.4,
                ),
              ),
              SizedBox(height: tv ? 10 : 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: tv ? 140 : 220),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(tv ? 6 : 8),
                    border: Border.all(color: ForjaShellColors.borderSubtle),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: tv ? 2 : 4),
                    itemCount: widget.updates.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: ForjaShellColors.borderSubtle,
                    ),
                    itemBuilder: (context, i) {
                      final u = widget.updates[i];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tv ? 8 : 12,
                          vertical: tv ? 6 : 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                u.packName,
                                style: TextStyle(
                                  color: ForjaShellColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize:
                                      tv ? ShellTokens.tvBodyFontSize : 13,
                                ),
                              ),
                            ),
                            Text(
                              'v${u.installedVersion} → v${u.remoteVersion}',
                              style: TextStyle(
                                color: ForjaShellColors.textSecondary,
                                fontSize: tv ? ShellTokens.tvMetaFontSize : 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: tv ? 14 : 24),
              Button(
                variant: ButtonVariant.primary,
                label:
                    _busy ? 'Updating…' : (count == 1 ? 'Update' : 'Update all'),
                expand: true,
                autofocus: tv,
                focusNode: _confirmFocus,
                onPressed: _busy ? null : _submit,
              ),
              SizedBox(height: tv ? 2 : 4),
              Center(
                child: Button(
                  variant: ButtonVariant.ghost,
                  label: 'Cancel',
                  focusNode: _cancelFocus,
                  onPressed: _busy ? null : widget.onCancel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
