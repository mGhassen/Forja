import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

/// A single color theme preset with its own personality.
class AppThemePreset {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color bgDark;
  final Color bgCard;
  final Color primaryColor;
  final Color accentColor;
  final Color gradientTint;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.bgDark,
    required this.bgCard,
    required this.primaryColor,
    required this.accentColor,
    required this.gradientTint,
  });

  BoxDecoration get backgroundDecoration => BoxDecoration(color: bgDark);

  BoxDecoration get backgroundDecorationFlat => BoxDecoration(color: bgDark);
}

class AppTheme {
  static const Color appBackground = Color(0xFF141414);
  static const Color appBackgroundLight = Color(0xFFF7F7F7);
  static const Color appCardLight = Color(0xFFFFFFFF);
  static const String defaultPresetId = 'emerald';

  static AppThemePreset get defaultPreset =>
      presets.firstWhere((p) => p.id == defaultPresetId);

  // ═══════════════════════════════════════════════════════════════════════════
  // Theme Presets
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<AppThemePreset> presets = [
    AppThemePreset(
      id: 'cinematic',
      name: 'Cinematic',
      description: 'Electric violet & cyan — the original vibe',
      icon: Icons.movie_filter,
      bgDark: appBackground,
      bgCard: Color(0xFF1C1C1C),
      primaryColor: Color(0xFF7C4DFF),
      accentColor: Color(0xFF00E5FF),
      gradientTint: appBackground,
    ),
    AppThemePreset(
      id: 'midnight',
      name: 'Midnight Black',
      description: 'Pure AMOLED black — sleek and minimal',
      icon: Icons.dark_mode,
      bgDark: appBackground,
      bgCard: Color(0xFF1C1C1C),
      primaryColor: Color(0xFFB0B0B0),
      accentColor: Color(0xFF4A4A4A),
      gradientTint: appBackground,
    ),
    AppThemePreset(
      id: 'royal_purple',
      name: 'Royal Purple',
      description: 'Deep purple with hot pink sparks',
      icon: Icons.auto_awesome,
      bgDark: appBackground,
      bgCard: Color(0xFF1C1C1C),
      primaryColor: Color(0xFFBB86FC),
      accentColor: Color(0xFFFF4081),
      gradientTint: appBackground,
    ),
    AppThemePreset(
      id: 'crimson',
      name: 'Crimson',
      description: 'Dark and intense — blood red energy',
      icon: Icons.local_fire_department,
      bgDark: appBackground,
      bgCard: Color(0xFF1C1C1C),
      primaryColor: Color(0xFFFF1744),
      accentColor: Color(0xFFFF6D00),
      gradientTint: appBackground,
    ),
    AppThemePreset(
      id: 'ocean',
      name: 'Ocean',
      description: 'Deep navy tones with teal highlights',
      icon: Icons.water,
      bgDark: appBackground,
      bgCard: Color(0xFF1C1C1C),
      primaryColor: Color(0xFF00BCD4),
      accentColor: Color(0xFF26C6DA),
      gradientTint: appBackground,
    ),
    AppThemePreset(
      id: 'emerald',
      name: 'Emerald',
      description: 'Dark forest vibes with neon green',
      icon: Icons.park,
      bgDark: appBackground,
      bgCard: Color(0xFF1C1C1C),
      primaryColor: Color(0xFF00E676),
      accentColor: Color(0xFF69F0AE),
      gradientTint: appBackground,
    ),
    AppThemePreset(
      id: 'sunset',
      name: 'Sunset',
      description: 'Warm amber tones with golden glow',
      icon: Icons.wb_twilight,
      bgDark: appBackground,
      bgCard: Color(0xFF1C1C1C),
      primaryColor: Color(0xFFFFAB00),
      accentColor: Color(0xFFFF6D00),
      gradientTint: appBackground,
    ),
  ];

  /// Notifier that broadcasts the current theme preset.
  static final ValueNotifier<AppThemePreset> themeNotifier =
      ValueNotifier<AppThemePreset>(defaultPreset);

  /// Current active preset (shorthand).
  static AppThemePreset get current => themeNotifier.value;

  // ═══════════════════════════════════════════════════════════════════════════
  // Backward-compatible const accessors (used in const contexts throughout the app)
  // These always return the default cinematic theme colors.
  // For theme-aware colors, use Theme.of(context).colorScheme or AppTheme.current.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Default primary color (const). For dynamic theme color, use `current.primaryColor`.
  static const Color primaryColor = Color(0xFF7C4DFF); // Electric Violet
  /// Default accent color (const). For dynamic theme color, use `current.accentColor`.
  static const Color accentColor = Color(0xFF00E5FF); // Cyan Accent

  static Color get bgDark => isLightMode ? appBackgroundLight : current.bgDark;
  static Color get bgCard => isLightMode ? appCardLight : current.bgCard;

  /// Whether light mode is currently active (cached from notifier).
  static bool get isLightMode => SettingsService.lightModeNotifier.value;

  static BoxDecoration get backgroundDecoration => effectiveBackground;
  static BoxDecoration get backgroundDecorationFlat => effectiveBackground;

  /// Returns the correct background based on light mode state.
  static BoxDecoration get effectiveBackground =>
      BoxDecoration(color: isLightMode ? appBackgroundLight : current.bgDark);

  static ThemeData get themeData {
    final preset = current;
    const buttonRadius = BorderRadius.all(Radius.circular(6));

    if (isLightMode) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: appBackgroundLight,
        primaryColor: preset.primaryColor,
        colorScheme: ColorScheme.light(
          primary: preset.primaryColor,
          secondary: preset.accentColor,
          surface: appCardLight,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
          displayLarge: GoogleFonts.bebasNeue(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.black87),
          displayMedium: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black87),
          titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
          labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF6B7280)),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
            backgroundColor: preset.primaryColor,
            foregroundColor: Colors.black87,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            foregroundColor: Colors.black87,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            shape: const CircleBorder(),
          ),
        ),
      );
    }
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: preset.bgDark,
      primaryColor: preset.primaryColor,
      colorScheme: ColorScheme.dark(
        primary: preset.primaryColor,
        secondary: preset.accentColor,
        surface: preset.bgCard,
        onSurface: const Color(0xFFF5F5F7),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.bebasNeue(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
        displayMedium: GoogleFonts.bebasNeue(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFFF5F5F7)),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF9CA3AF)),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFF5F5F7)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF9CA3AF)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
          backgroundColor: preset.bgCard,
          foregroundColor: const Color(0xFFF5F5F7),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
          side: const BorderSide(color: Color(0xFF4B5563)),
          foregroundColor: const Color(0xFFF5F5F7),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: const CircleBorder(),
          foregroundColor: const Color(0xFFF5F5F7),
        ),
      ),
    );
  }

  /// Hydrate the current theme from saved settings at app startup.
  static Future<void> initTheme() async {
    final id = await SettingsService().getThemePreset();
    final match = presets.where((p) => p.id == id);
    if (match.isNotEmpty) {
      themeNotifier.value = match.first;
    }
  }

  /// Change the theme and persist the choice.
  static Future<void> setPreset(String id) async {
    final match = presets.where((p) => p.id == id);
    if (match.isNotEmpty) {
      themeNotifier.value = match.first;
      await SettingsService().setThemePreset(id);
    }
  }
}

class FocusableControl extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autoFocus;
  final double borderRadius;
  final Color? glowColor;
  final double scaleOnFocus;

  const FocusableControl({
    super.key,
    required this.child,
    this.onTap,
    this.autoFocus = false,
    this.borderRadius = 12.0,
    this.glowColor,
    this.scaleOnFocus = 1.0, // Changed default from 1.05 to 1.0 (no zoom)
  });

  @override
  State<FocusableControl> createState() => _FocusableControlState();
}

class _FocusableControlState extends State<FocusableControl> with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: widget.scaleOnFocus).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateState(bool active) {
    if (active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightMode = AppTheme.isLightMode;

    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: (f) {
        setState(() => _isFocused = f);
        _updateState(f || _isHovered);
      },
      onKeyEvent: (node, event) {
        if (widget.onTap != null && event is KeyDownEvent && 
           (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
             widget.onTap!(); 
             return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _updateState(true);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _updateState(_isFocused);
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: lightMode
              // Light mode: no scale animation, no glow
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                  child: widget.child,
                )
              : AnimatedBuilder(
                  animation: _scale,
                  builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      boxShadow: (_isFocused || _isHovered) &&
                              widget.glowColor != null
                          ? [
                              BoxShadow(
                                color: widget.glowColor!
                                    .withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: widget.child,
                  ),
                ),
        ),
      ),
    );
  }
}
