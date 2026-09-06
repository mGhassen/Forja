import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/addons/settings_addon_catalog.dart';
import 'package:forja/features/settings/addons/settings_addon_deactivate.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/p2p_streaming_ack_dialog.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

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
    SettingsAddonId.iptv => visibility.iptvNav,
    SettingsAddonId.liveSports => visibility.liveMatchesNav,
    SettingsAddonId.lan => lanEnabled,
    _ => false,
  };
}

/// Nav id for Addons-gated host features (RFC-086).
String? addonFeatureNavId(String addonId) => switch (addonId) {
  SettingsAddonId.iptv => 'iptv',
  SettingsAddonId.liveSports => 'live_matches',
  _ => null,
};

/// Writes Addons master enable — call from the row OK / click.
Future<void> setAddonMasterEnabled(
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
      if (!ok || !context.mounted) return;
      await notifier.patch((s) => s.copyWith(p2pAcknowledged: true));
    }
  }

  final featureNavId = addonFeatureNavId(addonId);
  switch (addonId) {
    case SettingsAddonId.torrent:
      await settings.setPlaySourceTorrentEnabled(val);
      await notifier.patch((s) => s.copyWith(playSourceTorrent: val));
    case SettingsAddonId.stremio:
      await settings.setPlaySourceStremioEnabled(val);
      await notifier.patch((s) => s.copyWith(playSourceStremio: val));
    case SettingsAddonId.nuvio:
      await settings.setPlaySourceNuvioEnabled(val);
      await notifier.patch((s) => s.copyWith(playSourceNuvio: val));
    case SettingsAddonId.debrid:
      await settings.setUseDebridForStreams(val);
      ref
          .read(settingsDebridProvider.notifier)
          .patch((s) => s.copyWith(useDebrid: val));
    case SettingsAddonId.iptv:
    case SettingsAddonId.liveSports:
      await settings.setAddonFeatureEnabled(featureNavId!, val);
      if (!val) {
        noteNavigationDirty();
        await settings.setNavbarTabVisible(featureNavId, false);
        if (addonId == SettingsAddonId.iptv) {
          await notifier.patch((s) => s.copyWith(iptvEpgEnabled: false));
        }
      }
    case SettingsAddonId.lan:
      await LanPrefs.instance.setLanServerEnabled(val);
  }

  if (!val) {
    await deactivateAddonChildren(addonId);
  }

  schedulePreferencesSyncPush();
  if (!val && featureNavId != null) {
    await scheduleNavigationSyncPush();
  }
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
  bool _hovered = false;
  bool _busy = false;
  bool? _optimisticEnabled;

  bool get _chromeActive => _focused || _hovered;

  @override
  void initState() {
    super.initState();
    if (widget.addonId == SettingsAddonId.lan) {
      _hydrateLan();
    }
  }

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
      await setAddonMasterEnabled(
        ref,
        context,
        addonId: widget.addonId,
        val: val,
      );
      if (widget.addonId == SettingsAddonId.lan && mounted) {
        setState(() => _lanEnabled = val);
      }
    } catch (e, st) {
      debugPrint('[AddonToggle] ${widget.addonId} failed: $e\n$st');
      if (mounted) setState(() => _optimisticEnabled = null);
      rethrow;
    } finally {
      _busy = false;
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

    final switchChrome = ForjaSwitch(
      value: enabled,
      onChanged: null,
      scale: ForjaSwitch.settingsScale,
      emphasized: _chromeActive,
    );

    if (widget.chromeOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IgnorePointer(child: switchChrome),
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
          ensureVisibleMode: ShellTvEnsureVisibleMode.item,
          onLeftEdge: widget.onLeftEdge,
          onFocusChange: (f) {
            if (_focused == f) return;
            setState(() => _focused = f);
          },
          onHoverChange: (h) {
            if (_hovered == h) return;
            setState(() => _hovered = h);
          },
          child: SizedBox(
            width: 56,
            height: 44,
            child: Center(child: IgnorePointer(child: switchChrome)),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        if (_hovered) return;
        setState(() => _hovered = true);
      },
      onExit: (_) {
        if (!_hovered) return;
        setState(() => _hovered = false);
      },
      cursor: SystemMouseCursors.click,
      child: ForjaSwitch(
        value: enabled,
        onChanged: (v) => unawaited(_flipTo(v)),
        scale: ForjaSwitch.settingsScale,
        emphasized: _chromeActive,
      ),
    );
  }
}
