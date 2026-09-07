import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/lib/pack_assets.dart';

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

  /// Display source: Flutter `assets/…`, absolute pack file path, or http(s).
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
    if (asset == null || asset.isEmpty) return _materialIcon();

    // Tint via Image.color so errorBuilder Material glyphs are not wrapped in
    // ColorFiltered (failed IPTV host asset used to leave an empty rail slot).
    Widget fallback(BuildContext _, Object _, StackTrace? _) => _materialIcon();

    if (asset.startsWith('assets/')) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: fallback,
      );
    }
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return Image.network(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: fallback,
      );
    }
    final file = PackAssets.asLocalFile(asset) ?? File(asset);
    if (!file.existsSync()) return _materialIcon();
    return Image.file(
      file,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: fallback,
    );
  }

  Widget _materialIcon() {
    return Icon(
      selected ? destination.activeIcon : destination.icon,
      color: color,
      size: size,
    );
  }
}

typedef TabBuilder = Widget Function();
