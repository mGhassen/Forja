import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

/// WebStreamr hub body - countries, extractors, resolutions, MFP, Flare, TMDB.
class SettingsWebstreamrSection extends ConsumerStatefulWidget {
  const SettingsWebstreamrSection({super.key});

  @override
  ConsumerState<SettingsWebstreamrSection> createState() =>
      _SettingsWebstreamrSectionState();
}

class _SettingsWebstreamrSectionState
    extends ConsumerState<SettingsWebstreamrSection> {
  bool _saving = false;
  bool _hydrated = false;
  Set<String> _enabledCountries = {};
  Set<String> _disabledExtractors = {};
  Set<String> _excludedResolutions = {};
  final _mfpUrl = TextEditingController();
  final _mfpPwd = TextEditingController();
  final _flareUrl = TextEditingController();
  final _tmdbTok = TextEditingController();

  void _hydrate(SettingsWebstreamrSnapshot snap) {
    _enabledCountries = Set.of(snap.enabledCountries);
    _disabledExtractors = Set.of(snap.disabledExtractors);
    _excludedResolutions = Set.of(snap.excludedResolutions);
    _mfpUrl.text = snap.mfpUrl;
    _mfpPwd.text = snap.mfpPwd;
    _flareUrl.text = snap.flareUrl;
    _tmdbTok.text = snap.tmdbTok;
    _hydrated = true;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WebStreamrSettings.setEnabledCountryCodes(
        _enabledCountries.toList(),
      );
      await WebStreamrSettings.setDisabledExtractors(
        _disabledExtractors.toList(),
      );
      await WebStreamrSettings.setExcludedResolutions(
        _excludedResolutions.toList(),
      );
      await WebStreamrSettings.setMediaFlowProxyUrl(_mfpUrl.text.trim());
      await WebStreamrSettings.setMediaFlowProxyPassword(_mfpPwd.text);
      await WebStreamrSettings.setFlareSolverrUrl(_flareUrl.text.trim());
      await WebStreamrSettings.setTmdbAccessToken(_tmdbTok.text.trim());
      await WebStreamrService.init();
      await ref.read(settingsWebstreamrProvider.notifier).reload();
      if (!mounted) return;
      ForjaToast.success('WebStreamr settings saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _mfpUrl.dispose();
    _mfpPwd.dispose();
    _flareUrl.dispose();
    _tmdbTok.dispose();
    super.dispose();
  }

  Widget _chipWrap({
    required List<String> ids,
    required Set<String> selected,
    required void Function(String id, bool on) onToggle,
    String Function(String id)? labelOf,
  }) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in ids)
            Builder(
              builder: (context) {
                final on = selected.contains(id);
                final label = labelOf?.call(id) ?? id;
                final chip = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: on
                        ? ForjaShellColors.brandGreen.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: on
                          ? ForjaShellColors.brandGreen
                          : ForjaShellColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: on
                          ? ForjaShellColors.brandGreen
                          : ForjaShellColors.textSecondary,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                );
                if (!tv) {
                  return GestureDetector(
                    onTap: () => onToggle(id, !on),
                    child: chip,
                  );
                }
                return shellFocusableTap(
                  context: context,
                  onTap: () => onToggle(id, !on),
                  borderRadius: 8,
                  scaleOnFocus: 1.0,
                  showFocusBorder: true,
                  showFocusFill: true,
                  tvTabId: 'settings',
                  tvZone: ShellTvZone.settings,
                  child: chip,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: ForjaShellColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsWebstreamrProvider);
    final snap = async.valueOrNull;
    if (async.isLoading && snap == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ForjaShellColors.brandGreen,
            ),
          ),
        ),
      );
    }
    if (snap == null) return const SizedBox.shrink();
    if (!_hydrated) _hydrate(snap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Country sources',
          children: [
            _hint('Pick which language/region sources to query on Play.'),
            _chipWrap(
              ids: WebStreamrSettings.allCountryCodes,
              selected: _enabledCountries,
              labelOf: (cc) => cc.toUpperCase(),
              onToggle: (cc, on) => setState(() {
                if (on) {
                  _enabledCountries.add(cc);
                } else {
                  _enabledCountries.remove(cc);
                }
              }),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Disabled extractors',
          children: [
            _hint('Tap to disable. The "external" fallback always stays on.'),
            _chipWrap(
              ids: WebStreamrSettings.allExtractorIds,
              selected: _disabledExtractors,
              onToggle: (id, on) => setState(() {
                if (on) {
                  _disabledExtractors.add(id);
                } else {
                  _disabledExtractors.remove(id);
                }
              }),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Excluded resolutions',
          children: [
            _hint('Streams matching these resolutions are filtered out.'),
            _chipWrap(
              ids: WebStreamrSettings.allResolutions,
              selected: _excludedResolutions,
              onToggle: (r, on) => setState(() {
                if (on) {
                  _excludedResolutions.add(r);
                } else {
                  _excludedResolutions.remove(r);
                }
              }),
            ),
          ],
        ),
        SettingsGroup(
          label: 'MediaFlow Proxy',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hint(
                    'Optional - enables MFP-routed extractors (Voe etc.).',
                  ),
                  SettingsTextField(
                    controller: _mfpUrl,
                    label: 'MFP URL',
                    hint: 'https://your-mfp.example.com',
                  ),
                  const SizedBox(height: 12),
                  SettingsTextField(
                    controller: _mfpPwd,
                    label: 'MFP Password',
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'FlareSolverr',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hint(
                    'Optional - used for Cloudflare-protected hosts.',
                  ),
                  SettingsTextField(
                    controller: _flareUrl,
                    label: 'FlareSolverr URL',
                    hint: 'http://localhost:8191/v1',
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'TMDB access token',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hint(
                    'Required for sources that translate IMDb→TMDB locally.',
                  ),
                  SettingsTextField(
                    controller: _tmdbTok,
                    label: 'TMDB v4 Bearer token',
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ForjaButton.primary(
            label: 'Save',
            icon: Icons.save_rounded,
            busy: _saving,
            height: 36,
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}
