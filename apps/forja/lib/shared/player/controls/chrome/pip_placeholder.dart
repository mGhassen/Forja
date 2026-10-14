import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Corner notice while desktop PiP plays in the separate float window.
/// Keeps the shell clickable (route is non-opaque).
class PipPlaceholder extends StatelessWidget {
  const PipPlaceholder({
    super.key,
    required this.onExpand,
  });

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Material(
          color: const Color(0xE6121212),
          borderRadius: BorderRadius.circular(12),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_in_picture_alt_rounded,
                  size: ShellPaintScope.iconOf(context, 22),
                  color: Colors.white70,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Playing in picture-in-picture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onExpand,
                  child: const Text(
                    'Expand',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
