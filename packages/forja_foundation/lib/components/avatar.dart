import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Size scale for [Avatar].
enum AvatarSize {
  sm,
  md,
  lg,
}

/// Circular avatar — image, initials, or icon fallback.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.icon,
    this.size = AvatarSize.md,
    this.backgroundColor,
  });

  final String? imageUrl;
  final String? initials;
  final IconData? icon;
  final AvatarSize size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dim = switch (size) {
      AvatarSize.sm => 28.0,
      AvatarSize.md => 40.0,
      AvatarSize.lg => 56.0,
    };
    final fontSize = switch (size) {
      AvatarSize.sm => 11.0,
      AvatarSize.md => 14.0,
      AvatarSize.lg => 18.0,
    };
    final iconSize = switch (size) {
      AvatarSize.sm => 14.0,
      AvatarSize.md => 20.0,
      AvatarSize.lg => 28.0,
    };

    Widget child;
    final url = imageUrl?.trim();
    if (url != null &&
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        width: dim,
        height: dim,
        errorBuilder: (_, _, _) => _fallback(
          theme,
          fontSize,
          iconSize,
        ),
      );
    } else {
      child = _fallback(theme, fontSize, iconSize);
    }

    return ClipOval(
      child: Container(
        width: dim,
        height: dim,
        color: backgroundColor ?? theme.surfaceElevated,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _fallback(
    ForjaThemeExtension theme,
    double fontSize,
    double iconSize,
  ) {
    if (initials != null && initials!.trim().isNotEmpty) {
      return Text(
        initials!.trim().toUpperCase(),
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Icon(
      icon ?? Icons.person,
      size: iconSize,
      color: theme.textSecondary,
    );
  }
}
