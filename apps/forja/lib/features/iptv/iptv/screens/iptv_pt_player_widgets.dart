part of 'iptv_pt_player_screen.dart';

class _SourceChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  const _SourceChip({
    required this.label,
    required this.onTap,
    this.tvRowId,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  Widget build(BuildContext context) {
    return iptvTap(
      context: context,
      onTap: onTap,
      borderRadius: 20,
      scaleOnFocus: 1.0,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: IptvShellStyle.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded,
                color: IptvShellStyle.accent, size: 16),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
