import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/host/packs/pack_assets.dart';

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

class NavDestinationIcon extends StatefulWidget {
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
  State<NavDestinationIcon> createState() => _NavDestinationIconState();
}

class _NavDestinationIconState extends State<NavDestinationIcon>
    with WidgetsBindingObserver {
  /// Remount network glyphs after resume so a failed CDN load retries.
  int _networkEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final asset = widget.destination.iconAsset?.trim() ?? '';
    if (!asset.startsWith('http://') && !asset.startsWith('https://')) {
      return;
    }
    setState(() => _networkEpoch++);
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final selected = widget.selected;
    final color = widget.color;
    final size = widget.size;
    final asset = destination.iconAsset?.trim();
    if (asset == null || asset.isEmpty) return _materialIcon();

    // Decode at device pixels. FilterQuality.low (bilinear) — none looks
    // 8-bit under rail focus scale; medium LANCZOS rings hard-edged pack
    // PNGs into a 1px ghost square. Avoid Image.color (Impeller often paints
    // a hairline bounds rect with srcIn).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(1, 512);

    Widget fallback(BuildContext _, Object _, StackTrace? _) => Icon(
      selected ? destination.activeIcon : destination.icon,
      // White so outer ColorFiltered srcIn resolves to [color].
      color: Colors.white,
      size: size,
    );

    final Image image;
    if (asset.startsWith('assets/')) {
      image = Image.asset(
        asset,
        width: size,
        height: size,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        errorBuilder: fallback,
      );
    } else if (asset.startsWith('http://') || asset.startsWith('https://')) {
      image = Image.network(
        asset,
        key: ValueKey('nav-net-$asset-$_networkEpoch'),
        width: size,
        height: size,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        errorBuilder: fallback,
      );
    } else {
      final file = PackAssets.asLocalFile(asset) ?? File(asset);
      if (!file.existsSync()) return _materialIcon();
      image = Image.file(
        file,
        width: size,
        height: size,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        errorBuilder: fallback,
      );
    }

    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: image,
    );
  }

  Widget _materialIcon() {
    final destination = widget.destination;
    return Icon(
      widget.selected ? destination.activeIcon : destination.icon,
      color: widget.color,
      size: widget.size,
    );
  }
}

typedef TabBuilder = Widget Function();
