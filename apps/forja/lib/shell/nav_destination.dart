import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/catalog_pack_assets.dart';

class NavDestination {
  const NavDestination({
    required this.id,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.iconAsset,
  });

  final String id;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Resolved display source: Flutter `assets/…`, absolute file path, or http(s).
  final String? iconAsset;
}

class NavDestinationIcon extends StatelessWidget {
  const NavDestinationIcon({
    super.key,
    required this.destination,
    required this.selected,
    required this.color,
    this.size = 24,
  });

  final NavDestination destination;
  final bool selected;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = destination.iconAsset?.trim();
    if (asset != null && asset.isNotEmpty) {
      final image = _imageFor(asset);
      if (image != null) {
        // Same mute/accent as Material glyphs — pack PNGs are treated as masks.
        return ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: image,
        );
      }
    }
    return Icon(
      selected ? destination.activeIcon : destination.icon,
      color: color,
      size: size,
    );
  }

  Widget? _imageFor(String asset) {
    if (asset.startsWith('assets/')) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return Image.network(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    final file = CatalogPackAssets.asLocalFile(asset) ?? File(asset);
    if (!file.existsSync()) return null;
    return Image.file(
      file,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

typedef TabBuilder = Widget Function();
