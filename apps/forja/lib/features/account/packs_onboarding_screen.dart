import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/official_forjahq_install.dart';
import 'package:forja/shared/engine/official_forjahq_packs.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/forja_pack_choice_cards.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

TextStyle _onboardText({
  required Color color,
  required double size,
  FontWeight weight = FontWeight.w400,
  double height = 1.35,
  double? letterSpacing,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Post-login / upgrade packs step — same fractal + dark content shadow as
/// the TV/desktop account link welcome.
class PacksOnboardingScreen extends StatefulWidget {
  const PacksOnboardingScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<PacksOnboardingScreen> createState() => _PacksOnboardingScreenState();
}

class _PacksOnboardingScreenState extends State<PacksOnboardingScreen> {
  final FocusNode _installFocus =
      FocusNode(debugLabel: 'packs_onboard_install');
  final FocusNode _browseFocus = FocusNode(debugLabel: 'packs_onboard_browse');
  final FocusNode _skipFocus = FocusNode(debugLabel: 'packs_onboard_skip');

  bool _busy = false;
  String? _status;
  String? _error;
  int _done = 0;
  int _total = 0;

  bool get _isTv => PlatformInfo.isAndroidTv;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _installFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _installFocus.dispose();
    _browseFocus.dispose();
    _skipFocus.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await PacksOnboardingStore.markOnboarded();
    if (!mounted) return;
    widget.onFinished();
  }

  Future<void> _skip() async {
    if (_busy) return;
    await _finish();
  }

  Future<void> _browseCommunityPacks() async {
    final uri = Uri.parse(kCommunityPacksUrl);
    if (_isTv) {
      await Clipboard.setData(const ClipboardData(text: kCommunityPacksUrl));
      if (!mounted) return;
      setState(() {
        _status = 'URL copied. Open on your phone:\n$kCommunityPacksUrl';
      });
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Could not open Community Packs.');
    }
  }

  Future<void> _installOfficial() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Preparing official packs…';
      _done = 0;
      _total = 0;
    });

    try {
      final failures = await installOfficialForjaHqPacks(
        onProgress: ({
          required int done,
          required int total,
          required String status,
        }) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
            _status = status;
          });
        },
      );
      if (!mounted) return;
      if (failures.isNotEmpty) {
        setState(() {
          _error =
              'Installed with ${failures.length} error(s): ${failures.take(3).join(', ')}'
              '${failures.length > 3 ? '…' : ''}';
          _status = 'Finishing…';
        });
      }
      await _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Install failed. You can skip and add packs later in Settings.';
        _status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: FractalGlassGradient(params: FractalGlassParams.forTv),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  _isTv ? 56 : 40,
                  28,
                  _isTv ? 56 : 40,
                  36,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _ContentShadow(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icon/logo-dark.png',
                          width: _isTv ? 96 : 88,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Unlock the best experience',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            textStyle: _onboardText(
                              color: const Color(0xFFBFEFD0),
                              size: _isTv ? 30 : 26,
                              weight: FontWeight.w700,
                              height: 1.15,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Packs add catalogs, stream sources, live sports, and more. '
                          'Install the official ForjaHQ bundle for the full experience, '
                          'or browse Community Packs and pick your own.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            textStyle: _onboardText(
                              color: ForjaShellColors.textSecondary,
                              size: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_busy) ...[
                          if (_total > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (_done / _total).clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: ForjaShellColors.borderSubtle,
                                  color: ForjaShellColors.brandGreen,
                                ),
                              ),
                            ),
                          Text(
                            _status ?? 'Working…',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: _onboardText(
                                color: ForjaShellColors.textSecondary,
                                size: 14,
                              ),
                            ),
                          ),
                        ] else ...[
                          ForjaPackChoiceCards(
                            installFocusNode: _installFocus,
                            browseFocusNode: _browseFocus,
                            autofocusInstall: true,
                            communitySubtitle: _isTv
                                ? 'Copy the catalog URL for your phone'
                                : null,
                            onInstallOfficial: _installOfficial,
                            onBrowseCommunity: _browseCommunityPacks,
                          ),
                          const SizedBox(height: 20),
                          _SkipAction(
                            focusNode: _skipFocus,
                            onTap: _skip,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: _onboardText(
                                color: ForjaShellColors.textSecondary,
                                size: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        if (_status != null &&
                            !_busy &&
                            _status!.contains('http')) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            _status!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: _onboardText(
                                color: ForjaShellColors.textSecondary,
                                size: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft dark shadow under copy/actions — same recipe as TV account welcome.
class _ContentShadow extends StatelessWidget {
  const _ContentShadow({required this.child});

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

class _SkipAction extends StatelessWidget {
  const _SkipAction({
    required this.focusNode,
    required this.onTap,
  });

  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FocusableControl(
        focusNode: focusNode,
        onTap: onTap,
        borderRadius: 8,
        scaleOnFocus: 1.0,
        showFocusBorder: true,
        showFocusFill: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Skip for now',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              textStyle: _onboardText(
                color: ForjaShellColors.textSecondary,
                size: 15,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
