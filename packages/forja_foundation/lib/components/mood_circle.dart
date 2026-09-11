import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Generic circular mood / category selector.
class MoodCircle extends StatelessWidget {
  const MoodCircle({
    super.key,
    required this.label,
    this.imageUrl,
    this.selected = false,
    this.onTap,
    this.child,
    this.size = 72,
    this.focusNode,
  });

  final String label;
  final String? imageUrl;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? child;
  final double size;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final border = selected
        ? theme.brandGreen
        : theme.borderSubtle;
    final bg = selected
        ? ForjaShellColors.chipSelectedBg
        : theme.surfaceElevated;
    final url = imageUrl?.trim() ?? '';

    Widget content;
    if (child != null) {
      content = child!;
    } else if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      content = Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Icon(
          Icons.mood,
          color: theme.textSecondary,
          size: size * 0.4,
        ),
      );
    } else if (url.isNotEmpty) {
      content = Icon(Icons.mood, color: theme.textSecondary, size: size * 0.4);
    } else {
      content = Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            focusNode: focusNode,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                border: Border.all(color: border, width: selected ? 2.5 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
        SizedBox(height: theme.spaceSm),
        SizedBox(
          width: size + 8,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? theme.textPrimary : theme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
