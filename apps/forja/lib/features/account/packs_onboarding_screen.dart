import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/official_forjahq_packs.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
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
        _status = 'URL copied — open on your phone:\n$kCommunityPacksUrl';
      });
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Could not open Community Packs.');
    }
  }

  Future<List<OfficialForjaHqPack>> _resolveOfficialPacks() async {
    final byId = {
      for (final p in kOfficialForjaHqPacks) p.id: p,
    };
    try {
      final res = await http
          .get(Uri.parse(kPluginCatalogUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
      }
      final packs = decoded['packs'];
      if (packs is! List) {
        return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
      }
      final out = <OfficialForjaHqPack>[];
      for (final raw in packs) {
        if (raw is! Map) continue;
        if (raw['official'] != true) continue;
        final id = (raw['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) continue;
        final baked = byId[id];
        if (baked == null) continue;
        final name = (raw['name'] as String?)?.trim();
        out.add(
          OfficialForjaHqPack(
            id: baked.id,
            name: (name != null && name.isNotEmpty) ? name : baked.name,
            manifestUrl: baked.manifestUrl,
          ),
        );
      }
      if (out.isNotEmpty) return out;
    } catch (e) {
      debugPrint('[PacksOnboarding] catalog fetch failed: $e');
    }
    return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
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
      final targets = await _resolveOfficialPacks();
      final installed = await PluginRegistry.instance.listPacksRaw();
      final have = {
        for (final p in installed) p.sourceUrl.trim(),
      };
      final todo = targets
          .where((p) => !have.contains(p.manifestUrl.trim()))
          .toList(growable: false);

      if (todo.isEmpty) {
        await _finish();
        return;
      }

      setState(() {
        _total = todo.length;
        _status = 'Installing 0 of ${todo.length}…';
      });

      final failures = <String>[];
      for (var i = 0; i < todo.length; i++) {
        final pack = todo[i];
        if (!mounted) return;
        setState(() {
          _done = i;
          _status = 'Installing ${pack.name} (${i + 1}/${todo.length})…';
        });
        try {
          await PluginInstallCoordinator.instance.installManifest(
            pack.manifestUrl,
          );
        } catch (e) {
          debugPrint('[PacksOnboarding] install ${pack.id} failed: $e');
          failures.add(pack.name);
        }
      }

      if (!mounted) return;
      if (failures.isNotEmpty) {
        setState(() {
          _done = todo.length;
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
                          Row(
                            children: [
                              Expanded(
                                child: _ChoiceCard(
                                  focusNode: _installFocus,
                                  autofocus: true,
                                  icon: Icons.inventory_2_rounded,
                                  title: 'Official packs',
                                  subtitle:
                                      'Best experience — install the ForjaHQ bundle',
                                  accent: true,
                                  onTap: _installOfficial,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _ChoiceCard(
                                  focusNode: _browseFocus,
                                  icon: Icons.public_rounded,
                                  title: 'Community Packs',
                                  subtitle: _isTv
                                      ? 'Copy the catalog URL for your phone'
                                      : 'Browse and pick packs on the web',
                                  onTap: _browseCommunityPacks,
                                ),
                              ),
                            ],
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.focusNode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
    this.autofocus = false,
  });

  final FocusNode focusNode;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      focusNode: focusNode,
      autoFocus: autofocus,
      onTap: onTap,
      borderRadius: 16,
      scaleOnFocus: 1.02,
      showFocusBorder: true,
      showFocusFill: false,
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          final borderColor = accent
              ? ForjaShellColors.brandGreen.withValues(
                  alpha: focused ? 0.95 : 0.55,
                )
              : ForjaShellColors.borderSubtle.withValues(
                  alpha: focused ? 0.95 : 0.7,
                );
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 168),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: focused ? 0.42 : 0.28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: focused ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: accent
                      ? ForjaShellColors.brandGreen
                      : ForjaShellColors.textPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    textStyle: _onboardText(
                      color: ForjaShellColors.textPrimary,
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    textStyle: _onboardText(
                      color: ForjaShellColors.textSecondary,
                      size: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
