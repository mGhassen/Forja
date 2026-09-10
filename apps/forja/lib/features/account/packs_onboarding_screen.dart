import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/engine/packs/catalog/official_forjahq_install.dart';
import 'package:forja/shared/engine/packs/catalog/official_forjahq_packs.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_prompt.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/foundation/components/packs/forja_pack_choice_cards.dart';
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
  final FocusNode _confirmFocus =
      FocusNode(debugLabel: 'packs_onboard_confirm_install');
  final FocusNode _backFocus = FocusNode(debugLabel: 'packs_onboard_back');

  bool _busy = false;
  bool _loadingPicker = false;
  bool _picking = false;
  List<PluginInstallCandidate> _candidates = const [];
  Set<String> _selected = {};
  String? _status;
  String? _error;
  int _done = 0;
  int _total = 0;

  bool get _isTv => PlatformInfo.isAndroidTv;

  String _key(PluginInstallCandidate c) =>
      '${c.kind.name}|${c.manifestUrl.trim()}';

  int get _selectedCount => _candidates
      .where((c) => !c.alreadyInstalled && _selected.contains(_key(c)))
      .length;

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
    _confirmFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await PacksOnboardingStore.markOnboarded();
    if (!mounted) return;
    widget.onFinished();
  }

  Future<void> _skip() async {
    if (_busy || _loadingPicker) return;
    await _finish();
  }

  Future<void> _browseCommunityPacks() async {
    final uri = Uri.parse(kCommunityPacksUrl);
    if (_isTv) {
      await Clipboard.setData(const ClipboardData(text: kCommunityPacksUrl));
      if (!mounted) return;
      setState(() {
        _status = 'URL copied — open on your phone';
        _error = null;
      });
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Could not open Community Packs.');
    }
  }

  Future<void> _openOfficialPicker() async {
    if (_busy || _loadingPicker) return;
    setState(() {
      _loadingPicker = true;
      _error = null;
      _status = 'Loading official packs…';
    });
    try {
      final bundle = await resolveRecommendedBundle();
      final candidates = bundle != null
          ? await loadMissingBundlePackCandidates(bundle)
          : await loadMissingOfficialPackCandidates();
      if (!mounted) return;
      if (candidates.isEmpty) {
        setState(() {
          _loadingPicker = false;
          _status = null;
        });
        await _finish();
        return;
      }
      setState(() {
        _loadingPicker = false;
        _picking = true;
        _candidates = candidates;
        _selected = {
          for (final c in candidates)
            if (c.recommended && !c.alreadyInstalled) _key(c),
        };
        _status = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirmFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPicker = false;
        _status = null;
        _error =
            'Could not load official packs. Skip and add them later in Settings.';
      });
    }
  }

  void _backToChoice() {
    if (_busy) return;
    setState(() {
      _picking = false;
      _candidates = const [];
      _selected = {};
      _error = null;
      _status = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _installFocus.requestFocus();
    });
  }

  Future<void> _installSelected() async {
    if (_busy || _selectedCount == 0) return;
    final selected = [
      for (final c in _candidates)
        if (!c.alreadyInstalled && _selected.contains(_key(c))) c,
    ];
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Preparing official packs…';
      _done = 0;
      _total = selected.length;
    });

    try {
      final failures = await installSelectedOfficialPacks(
        selected,
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
      // refresh + hub Features activate run inside installSelectedOfficialPacks
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

  Widget _header({required bool picking}) {
    return Column(
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
          picking ? 'Choose official packs' : 'Unlock the best experience',
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
          picking
              ? 'Recommended packs are checked. Add or remove any, then Install.'
              : 'Packs add catalogs, stream sources, live sports, and more. '
                  'Pick official ForjaHQ packs, or browse Community Packs '
                  'and choose on the web.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            textStyle: _onboardText(
              color: ForjaShellColors.textSecondary,
              size: 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _officialPickerBody() {
    return _OfficialPicker(
      candidates: _candidates,
      selected: _selected,
      selectedCount: _selectedCount,
      confirmFocus: _confirmFocus,
      backFocus: _backFocus,
      onToggle: (c, value) {
        final key = _key(c);
        setState(() {
          if (value) {
            _selected.add(key);
          } else {
            _selected.remove(key);
          }
        });
      },
      onSelectRecommended: () {
        setState(() {
          _selected = {
            for (final c in _candidates)
              if (c.recommended && !c.alreadyInstalled) _key(c),
          };
        });
      },
      onSelectAll: () {
        setState(() {
          _selected = {
            for (final c in _candidates)
              if (!c.alreadyInstalled) _key(c),
          };
        });
      },
      onClear: () {
        setState(() => _selected = {});
      },
      onInstall: () => unawaited(_installSelected()),
      onBack: _backToChoice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padH = _isTv ? 56.0 : 40.0;
    // Fill the viewport while picking so Install stays pinned (Update Forja).
    final fillPicker = _picking && !_busy && !_loadingPicker;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: FractalGlassGradient(params: FractalGlassParams.forTv),
          ),
          SafeArea(
            child: fillPicker
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: (constraints.maxWidth - padH * 2)
                              .clamp(0.0, 640.0),
                          height: constraints.maxHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 28, 0, 36),
                            child: _ContentShadow(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _header(picking: true),
                                  const SizedBox(height: 24),
                                  Expanded(child: _officialPickerBody()),
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        textStyle: _onboardText(
                                          color:
                                              ForjaShellColors.textSecondary,
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
                      );
                    },
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(padH, 28, padH, 36),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _ContentShadow(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _header(picking: false),
                              const SizedBox(height: 32),
                              if (_busy) ...[
                                if (_total > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value:
                                            (_done / _total).clamp(0.0, 1.0),
                                        minHeight: 4,
                                        backgroundColor:
                                            ForjaShellColors.borderSubtle,
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
                              ] else if (_loadingPicker) ...[
                                Text(
                                  _status ?? 'Loading…',
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
                                      ? 'Choose packs on your phone\n$kCommunityPacksUrl'
                                      : null,
                                  onInstallOfficial: () =>
                                      unawaited(_openOfficialPicker()),
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
                                  !_loadingPicker) ...[
                                const SizedBox(height: 12),
                                Text(
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

class _OfficialPicker extends StatelessWidget {
  const _OfficialPicker({
    required this.candidates,
    required this.selected,
    required this.selectedCount,
    required this.confirmFocus,
    required this.backFocus,
    required this.onToggle,
    required this.onSelectRecommended,
    required this.onSelectAll,
    required this.onClear,
    required this.onInstall,
    required this.onBack,
  });

  final List<PluginInstallCandidate> candidates;
  final Set<String> selected;
  final int selectedCount;
  final FocusNode confirmFocus;
  final FocusNode backFocus;
  final void Function(PluginInstallCandidate c, bool value) onToggle;
  final VoidCallback onSelectRecommended;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onInstall;
  final VoidCallback onBack;

  String _key(PluginInstallCandidate c) =>
      '${c.kind.name}|${c.manifestUrl.trim()}';

  @override
  Widget build(BuildContext context) {
    final actionable = candidates.where((c) => !c.alreadyInstalled).toList();
    final allSelected = actionable.isNotEmpty &&
        actionable.every((c) => selected.contains(_key(c)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '$selectedCount selected',
              style: GoogleFonts.plusJakartaSans(
                textStyle: _onboardText(
                  color: ForjaShellColors.textSecondary,
                  size: 12,
                ),
              ),
            ),
            const Spacer(),
            _TextChip(
              label: 'Recommended',
              onTap: onSelectRecommended,
            ),
            const SizedBox(width: 8),
            _TextChip(
              label: 'Select all',
              onTap: allSelected ? null : onSelectAll,
            ),
            const SizedBox(width: 8),
            _TextChip(
              label: 'Clear',
              onTap: selectedCount == 0 ? null : onClear,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              color: ForjaShellColors.borderSubtle,
            ),
            itemBuilder: (context, i) {
              final c = candidates[i];
              return _OnboardPackRow(
                candidate: c,
                checked: c.alreadyInstalled || selected.contains(_key(c)),
                enabled: !c.alreadyInstalled,
                onChanged: (value) => onToggle(c, value),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ForjaButton(
          label: selectedCount == 1
              ? 'Install 1 pack'
              : 'Install $selectedCount packs',
          icon: Icons.download_rounded,
          expand: true,
          focusNode: confirmFocus,
          autofocus: true,
          onPressed: selectedCount == 0 ? null : onInstall,
        ),
        const SizedBox(height: 10),
        Center(
          child: FocusableControl(
            focusNode: backFocus,
            onTap: onBack,
            borderRadius: 8,
            scaleOnFocus: 1.0,
            showFocusBorder: true,
            showFocusFill: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Back',
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
        ),
      ],
    );
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return FocusableControl(
      onTap: onTap,
      borderRadius: 6,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            textStyle: _onboardText(
              color: enabled
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.textSecondary.withValues(alpha: 0.45),
              size: 12,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardPackRow extends StatelessWidget {
  const _OnboardPackRow({
    required this.candidate,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final PluginInstallCandidate candidate;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = candidate.displayName?.trim().isNotEmpty == true
        ? candidate.displayName!.trim()
        : 'Plugin pack';
    final desc = candidate.description?.trim();
    final tv = PlatformInfo.isAndroidTv;

    void flip() {
      if (!enabled) return;
      onChanged(!checked);
    }

    final checkbox = SizedBox(
      width: 28,
      height: 28,
      child: Checkbox(
        value: checked,
        onChanged: enabled ? (v) => onChanged(v == true) : null,
        activeColor: ForjaShellColors.brandGreen,
        checkColor: const Color(0xFF0B0A0A),
        side: BorderSide(
          color: ForjaShellColors.borderSubtle.withValues(alpha: 0.9),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ExcludeFocus(excluding: tv, child: checkbox),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ForjaHQ',
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary
                            .withValues(alpha: 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (candidate.recommended) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D1C).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color:
                                const Color(0xFFFF4D1C).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Recommended',
                          style: TextStyle(
                            color: Color(0xFFFF4D1C),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    color: enabled
                        ? ForjaShellColors.textPrimary
                        : ForjaShellColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!tv || !enabled) return row;

    return FocusableControl(
      onTap: flip,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: false,
      child: row,
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
