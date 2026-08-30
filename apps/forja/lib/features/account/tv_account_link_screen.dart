import 'package:flutter/material.dart';
import 'package:forja/features/account/device_link_connect_view.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum _TvLinkStep { welcome, connect, error }

/// Leanback account link: welcome → code/QR (not desktop login).
class TvAccountLinkScreen extends StatefulWidget {
  const TvAccountLinkScreen({
    super.key,
    required this.onAuthenticated,
    required this.onContinueAsGuest,
  });

  final VoidCallback onAuthenticated;
  final VoidCallback onContinueAsGuest;

  @override
  State<TvAccountLinkScreen> createState() => _TvAccountLinkScreenState();
}

class _TvAccountLinkScreenState extends State<TvAccountLinkScreen>
    with SingleTickerProviderStateMixin {
  _TvLinkStep _step = _TvLinkStep.welcome;
  String? _error;

  late final AnimationController _enter;

  final FocusNode _signInFocus = FocusNode(debugLabel: 'tv_link_sign_in');
  final FocusNode _guestFocus = FocusNode(debugLabel: 'tv_link_guest');
  final FocusNode _backFocus = FocusNode(debugLabel: 'tv_link_back');
  final FocusNode _retryFocus = FocusNode(debugLabel: 'tv_link_retry');

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _signInFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _signInFocus.dispose();
    _guestFocus.dispose();
    _backFocus.dispose();
    _retryFocus.dispose();
    super.dispose();
  }

  void _focus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });
  }

  void _openConnect() {
    setState(() {
      _error = null;
      _step = _TvLinkStep.connect;
    });
    _focus(_backFocus);
  }

  void _backToWelcome() {
    setState(() {
      _error = null;
      _step = _TvLinkStep.welcome;
    });
    _focus(_signInFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: AnimatedBuilder(
        animation: _enter,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_enter.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: FractalGlassGradient(params: FractalGlassParams.forTv),
              ),
              SafeArea(
                child: Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 28, 56, 36),
                      child: switch (_step) {
                        _TvLinkStep.welcome => _WelcomePage(
                          signInFocus: _signInFocus,
                          guestFocus: _guestFocus,
                          onSignIn: _openConnect,
                          onGuest: widget.onContinueAsGuest,
                        ),
                        _TvLinkStep.connect => _ConnectPage(
                          backFocus: _backFocus,
                          onBack: _backToWelcome,
                          onAuthenticated: widget.onAuthenticated,
                        ),
                        _TvLinkStep.error => _ErrorPage(
                          message: _error ?? 'Something went wrong.',
                          primaryFocus: _retryFocus,
                          secondaryFocus: _guestFocus,
                          onRetry: _openConnect,
                          onGuest: widget.onContinueAsGuest,
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Typography ───────────────────────────────────────────────────────────────

TextStyle _tvText({
  required Color color,
  required double size,
  FontWeight weight = FontWeight.w500,
  double height = 1.35,
  double letterSpacing = 0,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );
}

class _FlatAction extends StatelessWidget {
  const _FlatAction({
    required this.focusNode,
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.icon,
  });

  final FocusNode focusNode;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      focusNode: focusNode,
      autoFocus: autofocus,
      onTap: onTap,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: ForjaShellColors.brandGreen, size: 24),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: GoogleFonts.dmSans(
                textStyle: _tvText(
                  color: ForjaShellColors.textPrimary,
                  size: 15,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 1) Welcome / authenticate (two columns) ──────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.signInFocus,
    required this.guestFocus,
    required this.onSignIn,
    required this.onGuest,
  });

  final FocusNode signInFocus;
  final FocusNode guestFocus;
  final VoidCallback onSignIn;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _TvContentShadow(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _WelcomeLogo(),
              const SizedBox(height: 28),
              const _WelcomeTitle(),
              const SizedBox(height: 16),
              const _WelcomeBody(),
              const SizedBox(height: 32),
              Text(
                'Sign in with your phone or computer in under a minute.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  textStyle: _tvText(
                    color: ForjaShellColors.textSecondary,
                    size: 14,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SignInAction(focusNode: signInFocus, onTap: onSignIn),
              const SizedBox(height: 8),
              _FlatAction(
                focusNode: guestFocus,
                label: 'Continue as guest',
                onTap: onGuest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft dark shadow under copy/actions - no frost blur, fractal stays sharp.
class _TvContentShadow extends StatelessWidget {
  const _TvContentShadow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.78),
            blurRadius: 72,
            spreadRadius: 16,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
        child: child,
      ),
    );
  }
}

class _WelcomeLogo extends StatelessWidget {
  const _WelcomeLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/logo-dark.png',
      width: 96,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your cinema.\nOn the big screen.',
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(
        textStyle: _tvText(
          color: const Color(0xFFBFEFD0),
          size: 32,
          weight: FontWeight.w700,
          height: 1.1,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody();

  @override
  Widget build(BuildContext context) {
    return Text(
      'The couch is ready. So is Forja. Open a film, chase a series, '
      'catch the match, or flip through live TV.',
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        textStyle: _tvText(
          color: ForjaShellColors.textSecondary,
          size: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

class _SignInAction extends StatelessWidget {
  const _SignInAction({required this.focusNode, required this.onTap});

  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      focusNode: focusNode,
      autoFocus: true,
      onTap: onTap,
      borderRadius: 28,
      scaleOnFocus: 1.02,
      showFocusBorder: false,
      showFocusFill: false,
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: focused
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.brandGreen.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: ForjaShellColors.brandGreen.withValues(
                          alpha: 0.15,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.link_rounded,
                  color: Color(0xFF111827),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sign in',
                  style: GoogleFonts.outfit(
                    textStyle: _tvText(
                      color: const Color(0xFF111827),
                      size: 17,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: const Color(0xFF111827).withValues(alpha: 0.75),
                  size: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── 2) Code + QR ─────────────────────────────────────────────────────────────

class _ConnectPage extends StatelessWidget {
  const _ConnectPage({
    required this.backFocus,
    required this.onBack,
    required this.onAuthenticated,
  });

  final FocusNode backFocus;
  final VoidCallback onBack;
  final VoidCallback onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: _TvContentShadow(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/icon/logo-dark.png',
                    width: 88,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              DeviceLinkConnectView(
                backFocusNode: backFocus,
                autofocusBack: true,
                onBack: onBack,
                onAuthenticated: onAuthenticated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({
    required this.message,
    required this.primaryFocus,
    required this.secondaryFocus,
    required this.onRetry,
    required this.onGuest,
  });

  final String message;
  final FocusNode primaryFocus;
  final FocusNode secondaryFocus;
  final VoidCallback onRetry;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/icon/logo-dark.png',
              width: 72,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const Spacer(),
            _FlatAction(
              focusNode: secondaryFocus,
              label: 'Continue as guest',
              onTap: onGuest,
            ),
          ],
        ),
        const Spacer(),
        Text(
          'COULD NOT LINK',
          style: GoogleFonts.dmMono(
            textStyle: _tvText(
              color: const Color(0xFFF87171),
              size: 12,
              weight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            message,
            style: GoogleFonts.dmSans(
              textStyle: _tvText(
                color: ForjaShellColors.textPrimary,
                size: 20,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _FlatAction(
          focusNode: primaryFocus,
          autofocus: true,
          icon: Icons.refresh_rounded,
          label: 'Get a new code',
          onTap: onRetry,
        ),
        const Spacer(),
      ],
    );
  }
}
