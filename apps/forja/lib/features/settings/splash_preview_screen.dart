import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:storage/storage.dart';

class SplashPreviewScreen extends StatefulWidget {
  const SplashPreviewScreen({super.key});

  @override
  State<SplashPreviewScreen> createState() => _SplashPreviewScreenState();
}

class _SplashPreviewScreenState extends State<SplashPreviewScreen> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _autoDismissTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SplashOverlayContent(
          isLight: AppTheme.isLightMode,
        ),
      ),
    );
  }
}
