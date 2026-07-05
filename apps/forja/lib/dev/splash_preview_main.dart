import 'package:flutter/material.dart';
import 'package:forja/features/settings/splash_preview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashPreviewScreen(),
    ),
  );
}
