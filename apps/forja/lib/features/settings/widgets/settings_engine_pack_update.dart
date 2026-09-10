import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';

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

/// Pack name + optional deprecated tag when the manifest URL is gone.
class SettingsEnginePackTitle extends StatelessWidget {
  const SettingsEnginePackTitle({
    super.key,
    required this.name,
    this.deprecated = false,
  });

  final String name;
  final bool deprecated;

  static const _deprecatedRed = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: deprecated
                  ? _deprecatedRed
                  : ForjaShellColors.textPrimary,
            ),
          ),
        ),
        if (deprecated) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _deprecatedRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _deprecatedRed.withValues(alpha: 0.45),
              ),
            ),
            child: const Text(
              'deprecated',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: _deprecatedRed,
              ),
            ),
          ),
        ],
      ],
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
