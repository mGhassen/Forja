import 'dart:async';

import 'package:flutter/material.dart' hide Switch;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/addons/catalog.dart';
import 'package:forja/features/settings/addons/deactivate.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/shell/visibility_provider.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/features/settings/ui/p2p_streaming_ack_dialog.dart';

import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/playback/sources/debrid_js_resolve.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/components/switch.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
/// Current on/off for an Addons master row (same sources as [AddonMasterToggle]).
bool addonMasterEnabled({
  required String addonId,
  required SettingsPlaybackSnapshot? snap,
  required SettingsVisibility visibility,
  required bool debridEnabled,
  required bool lanEnabled,
}) {
  return switch (addonId) {
    SettingsAddonId.torrent => snap?.playSourceTorrent ?? false,
    SettingsAddonId.stremio => snap?.playSourceStremio ?? false,
    SettingsAddonId.nuvio => snap?.playSourceNuvio ?? false,
    SettingsAddonId.debrid => debridEnabled,
    SettingsAddonId.lan => lanEnabled,
    _ => false,
  };
}

/// Nav id for Addons-gated host features (RFC-086).
/// IPTV / Live Sports are pack-only — no host addon feature id.
String? addonFeatureNavId(String addonId) => null;

/// Writes Addons master enable — call from the row OK / click.
///
/// Returns `false` when the user cancelled (e.g. P2P ack) so callers can clear
/// optimistic UI instead of leaving the switch stuck on.
Future<bool> setAddonMasterEnabled(
  WidgetRef ref,
  BuildContext context, {
  required String addonId,
  required bool val,
}) async {
  final settings = SettingsService();
  final notifier = ref.read(settingsPlaybackProvider.notifier);
  debugPrint('[AddonToggle] set $addonId → $val');

  if (val &&
      (addonId == SettingsAddonId.torrent ||
          addonId == SettingsAddonId.stremio ||
          addonId == SettingsAddonId.nuvio)) {
    final snap = ref.read(settingsPlaybackProvider).valueOrNull;
    if (snap?.p2pAcknowledged != true) {
      final ok = await ensureP2pStreamingAcknowledged(context);
      if (!ok || !context.mounted) return false;
      await notifier.patch((s) => s.copyWith(p2pAcknowledged: true));
    }
  }

  switch (addonId) {
    case SettingsAddonId.torrent:
      notePreferencesDirty();
      await settings.setPlaySourceTorrentEnabled(val);
      await notifier.patch((s) => s.copyWith(playSourceTorrent: val));
    case SettingsAddonId.stremio:
      notePreferencesDirty();
      await settings.setPlaySourceStremioEnabled(val);
      await notifier.patch((s) => s.copyWith(playSourceStremio: val));
    case SettingsAddonId.nuvio:
      notePreferencesDirty();
      await settings.setPlaySourceNuvioEnabled(val);
      await notifier.patch((s) => s.copyWith(playSourceNuvio: val));
    case SettingsAddonId.debrid:
      if (val) {
        await syncDebridResolveCatalog();
        final plugins = installedDebridPlugins();
        final current = await settings.getMagnetResolvePluginId();
        final keep = plugins.any((p) => p.id == current) ? current : '';
        final id = keep.isNotEmpty
            ? keep
            : (plugins.isNotEmpty ? plugins.first.id : '');
        await settings.setMagnetResolvePluginId(id);
        var label = id;
        for (final p in plugins) {
          if (p.id == id) {
            label = p.name;
            break;
          }
        }
        ref.read(settingsDebridProvider.notifier).patch(
              (s) => s.copyWith(
                enabled: id.isNotEmpty,
                pluginId: id,
                pluginLabel: label,
              ),
            );
      } else {
        await settings.setMagnetResolvePluginId('');
        ref.read(settingsDebridProvider.notifier).patch(
              (s) => s.copyWith(enabled: false, pluginId: '', pluginLabel: ''),
            );
      }
    case SettingsAddonId.lan:
      await LanPrefs.instance.setLanServerEnabled(val);
  }

  if (!val) {
    await deactivateAddonChildren(addonId);
  }

  schedulePreferencesSyncPush();
  return true;
}

/// Master on/off chrome for an addon in the Addons list.
///
/// Prefer [setAddonMasterEnabled] from the row; this widget displays state
/// (and optional leanback / desktop direct flip when not [chromeOnly]).
class AddonMasterToggle extends ConsumerStatefulWidget {
  const AddonMasterToggle({
    super.key,
    required this.addonId,
    required this.visibility,
    this.focusNode,
    this.onLeftEdge,
    this.chromeOnly = false,
    this.optimisticEnabled,
  });

  final String addonId;
  final SettingsVisibility visibility;

  /// TV: owned by the parent row so → / ← can move row ↔ switch.
  final FocusNode? focusNode;

  /// TV: ← from the switch returns to the addon row.
  final VoidCallback? onLeftEdge;

  /// Visual switch only — parent row owns activation.
  final bool chromeOnly;

  /// Parent-held optimistic value while a row flip is in flight.
  final bool? optimisticEnabled;

  @override
  ConsumerState<AddonMasterToggle> createState() => _AddonMasterToggleState();
}

class _AddonMasterToggleState extends ConsumerState<AddonMasterToggle> {
  bool _lanEnabled = false;
  bool _focused = false;
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _busy = false;
  bool? _optimisticEnabled;

  @override
  void initState() {
    super.initState();
    if (widget.addonId == SettingsAddonId.lan) {
      _hydrateLan();
    }
  }

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  bool _chromeActiveFor(bool hovered) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: hovered,
        focused: _focused,
        context: context,
      );

  @override
  void didUpdateWidget(covariant AddonMasterToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.optimisticEnabled != oldWidget.optimisticEnabled &&
        widget.optimisticEnabled != null) {
      _optimisticEnabled = widget.optimisticEnabled;
    }
  }

  Future<void> _hydrateLan() async {
    _lanEnabled = await LanPrefs.instance.isLanServerEnabled();
    if (mounted) setState(() {});
  }

  Future<void> _flipTo(bool val) async {
    if (_busy) return;
    _busy = true;
    setState(() => _optimisticEnabled = val);
    try {
      final applied = await setAddonMasterEnabled(
        ref,
        context,
        addonId: widget.addonId,
        val: val,
      );
      if (!mounted) return;
      if (!applied) {
        setState(() => _optimisticEnabled = null);
        return;
      }
      if (widget.addonId == SettingsAddonId.lan) {
        setState(() => _lanEnabled = val);
      }
    } catch (e, st) {
      debugPrint('[AddonToggle] ${widget.addonId} failed: $e\n$st');
      if (mounted) setState(() => _optimisticEnabled = null);
      rethrow;
    } finally {
      _busy = false;
      // Always drop optimistic after the write attempt so UI follows KV /
      // providers (avoids switch stuck ON while Sources sees play-source off).
      if (mounted && _optimisticEnabled != null) {
        setState(() => _optimisticEnabled = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
    final visAsync = ref.watch(settingsVisibilityProvider);
    final visibility = visAsync.hasValue
        ? visAsync.requireValue
        : widget.visibility;
    final debridAsync = ref.watch(settingsDebridProvider);
    final debridEnabled = debridAsync.hasValue
        ? (debridAsync.requireValue.useDebrid)
        : false;
    final computed = addonMasterEnabled(
      addonId: widget.addonId,
      snap: snap,
      visibility: visibility,
      debridEnabled: debridEnabled,
      lanEnabled: _lanEnabled,
    );
    final optimistic = widget.optimisticEnabled ?? _optimisticEnabled;
    if (optimistic != null && optimistic == computed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            (widget.optimisticEnabled ?? _optimisticEnabled) == computed) {
          setState(() => _optimisticEnabled = null);
        }
      });
    }
    final enabled = optimistic ?? computed;

    Widget switchChrome(bool hovered) => Switch(
          value: enabled,
          onChanged: null,
          scale: Switch.settingsScale,
          emphasized: _chromeActiveFor(hovered),
        );

    if (widget.chromeOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IgnorePointer(child: switchChrome(false)),
      );
    }

    final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;
    if (leanback) {
      return Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              unawaited(_flipTo(!enabled));
              return null;
            },
          ),
        },
        child: shellFocusableTap(
          context: context,
          focusNode: widget.focusNode,
          onTap: () => unawaited(_flipTo(!enabled)),
          borderRadius: 20,
          scaleOnFocus: 1.0,
          showFocusRail: false,
          showFocusFill: true,
          showFocusBorder: true,
          tvTabId: 'settings',
          tvZone: ShellTvZone.settings,
          ensureVisibleMode: ShellPaintEnsureVisible.item,
          onLeftEdge: widget.onLeftEdge,
          onFocusChange: (f) {
            if (_focused == f) return;
            setState(() => _focused = f);
          },
          onHoverChange: _setHovered,
          child: ListenableBuilder(
            listenable: _hoveredN,
            builder: (context, _) => SizedBox(
              width: 56,
              height: 44,
              child: Center(
                child: IgnorePointer(
                  child: switchChrome(_hoveredN.value),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) => Switch(
          value: enabled,
          onChanged: (v) => unawaited(_flipTo(v)),
          scale: Switch.settingsScale,
          emphasized: _chromeActiveFor(_hoveredN.value),
        ),
      ),
    );
  }
}
