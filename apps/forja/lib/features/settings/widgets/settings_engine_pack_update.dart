import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';

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
            SettingsTextAction(
              label: 'Check again',
              onPressed: onCheckAgain,
            ),
        ],
      ),
    );
  }
}

/// Version line under each installed pack row.
class SettingsEnginePackVersionLine extends StatelessWidget {
  const SettingsEnginePackVersionLine({
    super.key,
    required this.meta,
  });

  final String meta;

  @override
  Widget build(BuildContext context) {
    return Text(
      meta,
      style: TextStyle(
        fontSize: 11,
        color: ForjaShellColors.textSecondary.withValues(alpha: 0.75),
      ),
    );
  }
}
