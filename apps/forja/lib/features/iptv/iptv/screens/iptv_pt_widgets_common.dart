part of 'iptv_pt_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Common widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PtAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  const _PtAppBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null) iptvBackButton(context, onTap: onBack),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 28),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final String tag;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final int? listIndex;
  const _SourceChip({
    required this.label,
    required this.tag,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? IptvShellStyle.chipSelectedBg
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: iptvTap(
            context: context,
            onTap: enabled ? onTap : null,
            borderRadius: 12,
            listIndex: listIndex,
            tvRowId: 'portal-sources',
            tvItemIndex: listIndex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tag,
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : IptvShellStyle.accent,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PORTAL LIST VIEW
// ─────────────────────────────────────────────────────────────────────────────
