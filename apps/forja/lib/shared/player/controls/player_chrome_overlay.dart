import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';

class PlayerFlatIconButton extends StatelessWidget {
  const PlayerFlatIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.active = false,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: active ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: label == null ? size : null,
          height: size,
          child: label == null
              ? Icon(icon, color: Colors.white, size: 22)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(label!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
        ),
      ),
    );
    return child;
  }
}

class PlayerTitleMeta extends StatelessWidget {
  const PlayerTitleMeta({
    super.key,
    required this.title,
    this.movie,
  });

  final String title;
  final Movie? movie;

  String? _metaLine() {
    final m = movie;
    if (m == null) return null;
    final parts = <String>[];
    if (m.genres.isNotEmpty) parts.add(m.genres.take(2).join(' | '));
    if (m.runtime > 0) {
      parts.add(WatchProgressBar.formatMinutes(m.runtime * 60000));
    }
    if (m.releaseDate.length >= 4) parts.add(m.releaseDate.substring(0, 4));
    return parts.isEmpty ? null : parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaLine();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta != null) ...[
          const SizedBox(height: 4),
          Text(
            meta,
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
