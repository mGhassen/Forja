import 'package:flutter/material.dart';
import 'forja_theme.dart';
import 'server_grid.dart';

class PlayerOverlayPanel extends StatelessWidget {
  const PlayerOverlayPanel({
    super.key,
    required this.providers,
    required this.activeProviderId,
    required this.onProviderSelect,
    this.onPrevious,
    this.onNext,
    this.autoNext = true,
    this.onAutoNextToggle,
    this.onDetails,
    this.onShuffle,
    this.onPip,
    this.showServerGrid = true,
  });

  final List<({String id, String name})> providers;
  final String? activeProviderId;
  final ProviderTap onProviderSelect;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool autoNext;
  final ValueChanged<bool>? onAutoNextToggle;
  final VoidCallback? onDetails;
  final VoidCallback? onShuffle;
  final VoidCallback? onPip;
  final bool showServerGrid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ForjaTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _NavBtn(label: 'Previous', icon: Icons.skip_previous, onTap: onPrevious),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NavBtn(label: 'Next', icon: Icons.skip_next, onTap: onNext),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _ChipBtn(
                label: 'AutoNext',
                active: autoNext,
                onTap: () => onAutoNextToggle?.call(!autoNext),
              ),
              _ChipBtn(label: 'Details', onTap: onDetails),
              _ChipBtn(
                label: 'Watch Party',
                enabled: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Watch Party — coming soon')),
                  );
                },
              ),
              _ChipBtn(label: 'Shuffle', primary: true, onTap: onShuffle),
              if (onPip != null)
                _ChipBtn(label: 'PiP', icon: Icons.picture_in_picture_alt, onTap: onPip),
            ],
          ),
          if (showServerGrid && providers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Servers',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            ServerGrid(
              providers: providers,
              activeId: activeProviderId,
              onSelect: onProviderSelect,
            ),
          ],
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: ForjaTheme.textPrimary,
        side: const BorderSide(color: ForjaTheme.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  const _ChipBtn({
    required this.label,
    this.onTap,
    this.active = false,
    this.primary = false,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool primary;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? ForjaTheme.primary
        : active
            ? ForjaTheme.primary.withValues(alpha: 0.2)
            : ForjaTheme.bgCard;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
