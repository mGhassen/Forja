import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/pack_hub_features.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_prompt.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/install/remote_pack_intent_store.dart';

import 'package:forja/shared/host/kit/plugin_nav.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_toast.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
/// Open pack install/uninstall picker inside Settings → Forja Packs (right pane).
///
/// Same drill pattern as [SettingsAddonDrill] — never a modal dialog.
class SettingsPackPromptDrill {
  static final ValueNotifier<PluginBatchInstallPrompt?> current =
      ValueNotifier<PluginBatchInstallPrompt?>(null);

  /// True while Install / Apply is downloading — Back must not tear this down.
  static final ValueNotifier<bool> applying = ValueNotifier<bool>(false);

  /// Focus before the prompt opened — restored on Back.
  static ShellTvFocusMemory? returnFocus;

  static void open(PluginBatchInstallPrompt prompt) {
    if (current.value == null) {
      returnFocus = ShellTvFocusCoordinator.memoryFor('settings');
    }
    current.value = prompt;
  }

  static void close() {
    applying.value = false;
    current.value = null;
  }

  static void clearReturnFocus() {
    returnFocus = null;
  }

  static ShellTvFocusMemory? takeReturnFocus() {
    final snap = returnFocus;
    returnFocus = null;
    return snap;
  }

  static bool get isOpen => current.value != null;

  static bool get isApplying => applying.value;

  /// Back / category change / Not now — close without applying.
  /// Remote-profile cloud sync no longer uses defer for installs (auto-download).
  /// Unchecked remote uninstall rows still defer purge until next boot/session.
  static Future<void> dismissWithoutApply() async {
    if (isApplying) {
      debugPrint('[PackPrompt] dismiss ignored — install in progress');
      return;
    }
    final prompt = current.value;
    if (prompt == null) return;
    for (final c in prompt.candidates) {
      if (c.alreadyInstalled || !c.fromRemoteProfile) continue;
      final url = c.manifestUrl.trim();
      if (url.isEmpty) continue;
      // Install confirms for cloud membership are gone; only uninstall defer remains
      // for deeplink/legacy remote uninstall batches if any.
      if (c.kind == PluginPackPromptKind.uninstall) {
        await PendingRemotePurgeStore.defer(url);
      }
    }
    close();
  }

  static String titleFor(PluginBatchInstallPrompt prompt) {
    final remote = prompt.hasRemoteProfile;
    final hasInstall =
        prompt.candidates.any((c) => c.kind == PluginPackPromptKind.install);
    final hasUninstall =
        prompt.candidates.any((c) => c.kind == PluginPackPromptKind.uninstall);
    if (remote && hasInstall && hasUninstall) return 'Sync packs';
    if (remote && hasUninstall && !hasInstall) return 'Uninstall packs';
    if (remote) return 'Install packs';
    return 'Install packs';
  }
}

/// Flat checkbox list for batch install/uninstall — fills the Settings detail
/// pane with a pinned Install footer (list scrolls; same shape as Update Forja).
class SettingsPackPromptPane extends StatefulWidget {
  const SettingsPackPromptPane({
    super.key,
    required this.prompt,
    required this.onDismiss,
  });

  final PluginBatchInstallPrompt prompt;
  final VoidCallback onDismiss;

  @override
  State<SettingsPackPromptPane> createState() => _SettingsPackPromptPaneState();
}

class _SettingsPackPromptPaneState extends State<SettingsPackPromptPane> {
  static const _listRowId = 'pack-prompt-list';
  static const _toolbarRowId = 'pack-prompt-toolbar';

  late Set<String> _selected;
  bool _busy = false;
  final FocusNode _selectAllFocus =
      FocusNode(debugLabel: 'pack_prompt_select_all');
  final FocusNode _clearFocus = FocusNode(debugLabel: 'pack_prompt_clear');
  final FocusNode _installFocus =
      FocusNode(debugLabel: 'pack_prompt_install');

  String _key(PluginInstallCandidate c) =>
      '${c.kind.name}|${c.manifestUrl.trim()}';

  @override
  void initState() {
    super.initState();
    // User picks packs — do not pre-check every actionable row.
    _selected = {};
  }

  @override
  void dispose() {
    _selectAllFocus.dispose();
    _clearFocus.dispose();
    _installFocus.dispose();
    super.dispose();
  }

  void _pageBackLeft() {
    ShellTvFocusCoordinator.tryPageBack('settings');
  }

  void _focusFirstPack() {
    final n = widget.prompt.candidates.length;
    for (var i = 0; i < n; i++) {
      if (ShellTvFocusCoordinator.focusRowItemExact(
        'settings',
        _listRowId,
        i,
      )) {
        return;
      }
    }
  }

  void _focusToolbar() {
    if (_selectAllFocus.canRequestFocus) {
      _selectAllFocus.requestFocus();
      return;
    }
    if (_clearFocus.canRequestFocus) {
      _clearFocus.requestFocus();
    }
  }

  Iterable<PluginInstallCandidate> get _actionable =>
      widget.prompt.candidates.where((c) => !c.alreadyInstalled);

  int get _selectedInstallCount => widget.prompt.candidates
      .where(
        (c) =>
            c.kind == PluginPackPromptKind.install &&
            !c.alreadyInstalled &&
            _selected.contains(_key(c)),
      )
      .length;

  int get _selectedUninstallCount => widget.prompt.candidates
      .where(
        (c) =>
            c.kind == PluginPackPromptKind.uninstall &&
            !c.alreadyInstalled &&
            _selected.contains(_key(c)),
      )
      .length;

  int get _selectedCount => _selectedInstallCount + _selectedUninstallCount;

  void _selectAllActionable() {
    setState(() {
      for (final c in _actionable) {
        _selected.add(_key(c));
      }
    });
  }

  void _clearActionable() {
    setState(() {
      for (final c in _actionable) {
        _selected.remove(_key(c));
      }
    });
  }

  Future<void> _deferRemote(PluginInstallCandidate c) async {
    if (!c.fromRemoteProfile) return;
    final url = c.manifestUrl.trim();
    if (c.kind == PluginPackPromptKind.uninstall) {
      await PendingRemotePurgeStore.defer(url);
    }
  }

  Future<void> _applySelected() async {
    if (_busy || _selectedCount == 0) return;
    setState(() => _busy = true);
    SettingsPackPromptDrill.applying.value = true;
    var installed = 0;
    var removed = 0;
    final failures = <String>[];
    final installedPacks = <EnginePack>[];
    try {
      final coordinator = PluginInstallCoordinator.instance;
      final registry = PluginRegistry.instance;
      for (final c in widget.prompt.candidates) {
        final url = c.manifestUrl.trim();
        final key = _key(c);
        if (c.alreadyInstalled) continue;
        if (!_selected.contains(key)) {
          await _deferRemote(c);
          continue;
        }
        final label = c.displayName?.trim().isNotEmpty == true
            ? c.displayName!.trim()
            : url;
        try {
          if (c.kind == PluginPackPromptKind.uninstall) {
            debugPrint('[PackPrompt] uninstall $label');
            final packs = await registry.listPacksRaw();
            EnginePack? victim;
            for (final p in packs) {
              if (p.sourceUrl == url) {
                victim = p;
                break;
              }
            }
            if (victim != null) {
              await PackHubFeatures.deactivate(victim);
            }
            await registry.removePack(url);
            await PendingRemotePurgeStore.clear(url);
            removed++;
          } else {
            debugPrint('[PackPrompt] install $label → $url');
            final pack = await coordinator.installManifest(url);
            await DeferredRemoteInstallStore.clear(url);
            installed++;
            installedPacks.add(pack);
            debugPrint('[PackPrompt] install ok $label');
          }
        } catch (e) {
          debugPrint('[PackPrompt] failed $label: $e');
          failures.add(label);
        }
      }
      // Refresh destinations first, then RFC-086 default-on (even if unmounted).
      if (installedPacks.isNotEmpty) {
        await PackHubFeatures.refreshAndActivateInstalled(installedPacks);
      } else if (removed > 0) {
        await PluginNavRegistry.refresh();
      }
      scheduleForjaSyncPush();
      if (!mounted) return;
      if (failures.isEmpty) {
        final bits = <String>[
          if (installed > 0)
            installed == 1 ? '1 pack installed' : '$installed packs installed',
          if (removed > 0)
            removed == 1 ? '1 pack removed' : '$removed packs removed',
        ];
        if (bits.isNotEmpty) ForjaToast.success(bits.join(' · '));
      } else {
        ForjaToast.error(
          'Pack sync: ${failures.length} failed'
          '${installed > 0 ? ', $installed ok' : ''}'
          ' (${failures.take(2).join(', ')}'
          '${failures.length > 2 ? '…' : ''})',
        );
      }
      widget.onDismiss();
    } finally {
      SettingsPackPromptDrill.applying.value = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notNow() async {
    if (_busy || SettingsPackPromptDrill.isApplying) return;
    setState(() => _busy = true);
    try {
      await SettingsPackPromptDrill.dismissWithoutApply();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _body {
    if (widget.prompt.hasRemoteProfile) {
      return 'These packs changed on your profile from another device. '
          'Choose what to apply here. The rest can wait in Forja Packs.';
    }
    return 'Choose which packs to download on this device. '
        'You can install the rest later from this page.';
  }

  String get _primaryLabel {
    if (_busy) return 'Working…';
    final i = _selectedInstallCount;
    final u = _selectedUninstallCount;
    if (i > 0 && u > 0) {
      return 'Apply ($i install · $u uninstall)';
    }
    if (u > 0) {
      return u == 1 ? 'Uninstall 1 pack' : 'Uninstall $u packs';
    }
    return i == 1 ? 'Install 1 pack' : 'Install $i packs';
  }

  @override
  Widget build(BuildContext context) {
    final actionable = _actionable.toList();
    final allSelected = actionable.isNotEmpty &&
        actionable.every((c) => _selected.contains(_key(c)));
    final candidates = widget.prompt.candidates;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final selectAllEnabled = !_busy && !allSelected;
    final clearEnabled = !_busy && _selectedCount > 0;

    // Header + list + footer pinned — only the pack rows scroll (Update Forja).
    // TV: vertical TvKitRow so ↑/↓ walk packs (ListView linear/spatial was
    // snapping every ↑ to Select all when neighbors were off-screen).
    Widget toolbar = Row(
      children: [
        Text(
          '$_selectedCount selected',
          style: const TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        SettingsTextAction(
          label: 'Select all',
          focusNode: tv && selectAllEnabled ? _selectAllFocus : null,
          tvRowId: tv ? _toolbarRowId : null,
          tvItemIndex: 0,
          tvZone: tv ? ShellTvZone.row : null,
          onLeftEdge: tv ? _pageBackLeft : null,
          onRightEdge: tv && clearEnabled
              ? () => _clearFocus.requestFocus()
              : null,
          onDownEdge: tv ? _focusFirstPack : null,
          onPressed: selectAllEnabled ? _selectAllActionable : null,
        ),
        SettingsTextAction(
          label: 'Clear',
          focusNode: tv && clearEnabled ? _clearFocus : null,
          tvRowId: tv ? _toolbarRowId : null,
          tvItemIndex: 1,
          tvZone: tv ? ShellTvZone.row : null,
          onLeftEdge: tv
              ? () {
                  if (selectAllEnabled) {
                    _selectAllFocus.requestFocus();
                  } else {
                    _pageBackLeft();
                  }
                }
              : null,
          onDownEdge: tv ? _focusFirstPack : null,
          onPressed: clearEnabled ? _clearActionable : null,
        ),
      ],
    );
    if (tv) {
      toolbar = TvKitRow(
        tabId: 'settings',
        rowId: _toolbarRowId,
        sortOrder: 10,
        itemCount: 2,
        child: toolbar,
      );
    }

    Widget list = ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: candidates.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: ForjaShellColors.borderSubtle,
      ),
      itemBuilder: (context, i) {
        final c = candidates[i];
        return _PackPromptRow(
          candidate: c,
          checked: c.alreadyInstalled || _selected.contains(_key(c)),
          enabled: !c.alreadyInstalled && !_busy,
          listIndex: i,
          listRowId: tv ? _listRowId : null,
          onLeftEdge: tv ? _pageBackLeft : null,
          onChanged: (value) {
            final key = _key(c);
            setState(() {
              if (value) {
                _selected.add(key);
              } else {
                _selected.remove(key);
              }
            });
          },
        );
      },
    );
    if (tv && candidates.isNotEmpty) {
      list = TvKitRow(
        tabId: 'settings',
        rowId: _listRowId,
        sortOrder: 20,
        itemCount: candidates.length,
        orientation: ShellTvRowOrientation.vertical,
        onFocusUp: _focusToolbar,
        onFocusDown: () {
          if (_installFocus.canRequestFocus) {
            _installFocus.requestFocus();
          }
        },
        child: list,
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _body,
          style: TextStyle(
            color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        toolbar,
        const SizedBox(height: 4),
        Expanded(child: list),
        const SizedBox(height: 16),
        SettingsFilledButton(
          label: _primaryLabel,
          icon: Icons.download_rounded,
          busy: _busy,
          expand: true,
          focusNode: tv ? _installFocus : null,
          onPressed: _busy || _selectedCount == 0
              ? null
              : () => unawaited(_applySelected()),
        ),
        const SizedBox(height: 8),
        Center(
          child: SettingsTextAction(
            label: 'Not now',
            color: ForjaShellColors.textSecondary,
            onLeftEdge: tv ? _pageBackLeft : null,
            onUpEdge: tv
                ? () {
                    if (_installFocus.canRequestFocus) {
                      _installFocus.requestFocus();
                    }
                  }
                : null,
            onPressed: _busy ? null : () => unawaited(_notNow()),
          ),
        ),
      ],
    );
    if (!tv) return body;
    return ShellTvDisableLinearFocus(child: body);
  }
}

/// Flat checkbox row — no card chrome (matches Community Packs list rows).
class _PackPromptRow extends StatelessWidget {
  const _PackPromptRow({
    required this.candidate,
    required this.checked,
    required this.enabled,
    required this.onChanged,
    this.listIndex,
    this.listRowId,
    this.onLeftEdge,
  });

  final PluginInstallCandidate candidate;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final int? listIndex;
  final String? listRowId;
  final VoidCallback? onLeftEdge;

  static String _labelize(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    return t
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final settled = candidate.alreadyInstalled;
    final uninstall = candidate.kind == PluginPackPromptKind.uninstall;
    final title = candidate.displayName?.trim().isNotEmpty == true
        ? candidate.displayName!.trim()
        : 'Plugin pack';
    final actionLabel = uninstall ? 'Uninstall' : 'Install';
    final settledLabel = uninstall ? 'Already removed' : 'Already on device';
    final desc = candidate.description?.trim();
    final tagsLine = candidate.tags
        .map(_labelize)
        .where((t) => t.isNotEmpty)
        .join(' · ');
    final version = candidate.version?.trim();
    final muted = settled
        ? ForjaShellColors.textSecondary
        : ForjaShellColors.textPrimary;

    void flip() {
      if (!enabled) return;
      onChanged(!checked);
    }

    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
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
          // TV: row owns focus — Checkbox must not steal a second node.
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
                    Flexible(
                      child: Text(
                        candidate.official ? 'ForjaHQ' : 'Community',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary
                              .withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (candidate.official) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ForjaShellColors.brandGreen
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: ForjaShellColors.brandGreen
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'Official',
                          style: TextStyle(
                            color: ForjaShellColors.brandGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (candidate.recommended) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D1C)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFF4D1C)
                                .withValues(alpha: 0.4),
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
                    if (version != null && version.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        version.startsWith('v') ? version : 'v$version',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary
                              .withValues(alpha: 0.55),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tagsLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tagsLine.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary
                          .withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  settled
                      ? settledLabel
                      : (desc != null && desc.isNotEmpty)
                          ? desc
                          : actionLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!tv || !enabled) return row;

    return shellFocusableTap(
      context: context,
      onTap: flip,
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: listRowId != null ? ShellTvZone.row : ShellTvZone.settings,
      tvRowId: listRowId,
      tvItemIndex: listIndex,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onLeftEdge: onLeftEdge,
      child: row,
    );
  }
}
