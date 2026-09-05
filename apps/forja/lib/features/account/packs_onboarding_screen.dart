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
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Post-login / upgrade packs step: Community Packs link + official install.
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
  final FocusNode _installFocus = FocusNode(debugLabel: 'packs_onboard_install');
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
        _error = 'Install failed. You can skip and add packs later in Settings.';
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
                padding: EdgeInsets.symmetric(
                  horizontal: _isTv ? 56 : 40,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ForjaLogoIdle(logoHeight: _isTv ? 88 : 72),
                      const SizedBox(height: 28),
                      Text(
                        'Unlock the best experience',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: ForjaShellColors.textPrimary,
                          fontSize: _isTv ? 28 : 24,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Packs add catalogs, stream sources, live sports, and more. '
                        'Install the official ForjaHQ bundle for the full experience, '
                        'or browse Community Packs and pick your own.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_busy) ...[
                        if (_total > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(
                              value: _total == 0
                                  ? null
                                  : (_done / _total).clamp(0.0, 1.0),
                              backgroundColor: ForjaShellColors.borderSubtle,
                              color: ForjaShellColors.brandGreen,
                            ),
                          ),
                        Text(
                          _status ?? 'Working…',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: ForjaShellColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        _ActionButton(
                          focusNode: _installFocus,
                          autofocus: true,
                          label: 'Install official ForjaHQ packs',
                          primary: true,
                          onTap: _installOfficial,
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          focusNode: _browseFocus,
                          label: _isTv
                              ? 'Copy Community Packs URL'
                              : 'Browse Community Packs',
                          onTap: _browseCommunityPacks,
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          focusNode: _skipFocus,
                          label: 'Skip for now',
                          onTap: _skip,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: ForjaShellColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (_status != null && !_busy && _status!.contains('http')) ...[
                        const SizedBox(height: 12),
                        SelectableText(
                          _status!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: ForjaShellColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.focusNode,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.autofocus = false,
  });

  final FocusNode focusNode;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      focusNode: focusNode,
      autoFocus: autofocus,
      onTap: onTap,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: primary,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: primary
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ForjaShellColors.brandGreen.withValues(alpha: 0.55),
                ),
              )
            : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: primary
                ? ForjaShellColors.brandGreen
                : ForjaShellColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
