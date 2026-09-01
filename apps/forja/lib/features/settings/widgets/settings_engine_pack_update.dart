import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';

/// Banner above installed packs when one or more updates are available.
class SettingsEnginePackUpdatesBar extends StatelessWidget {
  const SettingsEnginePackUpdatesBar({
    super.key,
    required this.updateCount,
    required this.checking,
    required this.onUpdateAll,
    required this.onCheckAgain,
    this.updating = false,
  });

  final int updateCount;
  final bool checking;
  final bool updating;
  final VoidCallback onUpdateAll;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    if (updateCount == 0 && !checking) return const SizedBox.shrink();

    final hasUpdates = updateCount > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hasUpdates
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.1)
              : ForjaShellColors.surfaceElevated.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasUpdates
                ? ForjaShellColors.brandGreen.withValues(alpha: 0.45)
                : ForjaShellColors.borderSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                hasUpdates
                    ? Icons.system_update_rounded
                    : Icons.sync_rounded,
                size: 18,
                color: hasUpdates
                    ? ForjaShellColors.brandGreen
                    : ForjaShellColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  checking
                      ? 'Checking for plugin updates…'
                      : hasUpdates
                      ? '$updateCount update${updateCount == 1 ? '' : 's'} available'
                      : 'All plugins are up to date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasUpdates
                        ? ForjaShellColors.brandGreen
                        : ForjaShellColors.textSecondary,
                  ),
                ),
              ),
              if (checking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasUpdates) ...[
                SettingsFilledButton(
                  label: updating ? 'Updating…' : 'Update all',
                  icon: Icons.download_rounded,
                  busy: updating,
                  onPressed: updating ? null : onUpdateAll,
                ),
              ] else
                TextButton(
                  onPressed: onCheckAgain,
                  child: const Text('Check again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green pill shown next to the pack version when an update exists.
class SettingsEnginePackUpdateBadge extends StatelessWidget {
  const SettingsEnginePackUpdateBadge({
    super.key,
    required this.remoteVersion,
  });

  final String remoteVersion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ForjaShellColors.brandGreen.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ForjaShellColors.brandGreen.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        'v$remoteVersion available',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ForjaShellColors.brandGreen,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Version + status line under each installed pack row.
class SettingsEnginePackVersionLine extends StatelessWidget {
  const SettingsEnginePackVersionLine({
    super.key,
    required this.meta,
    this.update,
  });

  final String meta;
  final EnginePackUpdateInfo? update;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          meta,
          style: TextStyle(
            fontSize: 11,
            color: ForjaShellColors.textSecondary.withValues(alpha: 0.75),
          ),
        ),
        if (update != null) SettingsEnginePackUpdateBadge(
          remoteVersion: update!.remoteVersion,
        ),
      ],
    );
  }
}

/// Optional highlight border when a pack has an update.
class SettingsEnginePackUpdateFrame extends StatelessWidget {
  const SettingsEnginePackUpdateFrame({
    super.key,
    required this.hasUpdate,
    required this.child,
  });

  final bool hasUpdate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!hasUpdate) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ForjaShellColors.brandGreen.withValues(alpha: 0.35),
        ),
        color: ForjaShellColors.brandGreen.withValues(alpha: 0.04),
      ),
      child: child,
    );
  }
}
