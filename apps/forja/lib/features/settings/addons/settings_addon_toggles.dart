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

/// Master on/off switch for an addon in the Addons list.
///
/// Reads/writes the same prefs as the old Sources / category toggles.
class AddonMasterToggle extends ConsumerStatefulWidget {
  const AddonMasterToggle({
    super.key,
    required this.addonId,
    required this.visibility,
    this.focusNode,
    this.onLeftEdge,
    this.chromeOnly = false,
    this.onProvideFlip,
  });

  final String addonId;
  final SettingsVisibility visibility;

  /// TV: owned by the parent row so → / ← can move row ↔ switch.
  final FocusNode? focusNode;

  /// TV: ← from the switch returns to the addon row.
  final VoidCallback? onLeftEdge;

  /// Visual switch only — parent row / OK owns activation ([onProvideFlip]).
  final bool chromeOnly;

  /// Registers the flip callback so the row can OK-activate the addon.
  final ValueChanged<VoidCallback>? onProvideFlip;

  @override
  ConsumerState<AddonMasterToggle> createState() => _AddonMasterToggleState();
}

class _AddonMasterToggleState extends ConsumerState<AddonMasterToggle> {
  final SettingsService _settings = SettingsService();
  bool _lanEnabled = false;
  bool _focused = false;
  bool _hovered = false;
  bool _busy = false;

  /// Holds the last user flip until providers catch up. Without this, invalidating
  /// [settingsVisibilityProvider] / playback reload flashes [AsyncLoading] and the
  /// switch falls back to a stale host [widget.visibility] — looks like OK did nothing.
  bool? _optimisticEnabled;

  bool get _chromeActive => _focused || _hovered;

  @override
  void initState() {
    super.initState();
    if (widget.addonId == SettingsAddonId.lan) {
      _hydrateLan();
    }
  }

  Future<void> _hydrateLan() async {
    _lanEnabled = await LanPrefs.instance.isLanServerEnabled();
    if (mounted) setState(() {});
  }

  Future<bool> _confirmP2pIfNeeded() async {
    final snap = ref.read(settingsPlaybackProvider).valueOrNull;
    if (snap?.p2pAcknowledged == true) return true;
    final ok = await ensureP2pStreamingAcknowledged(context);
    if (!ok || !mounted) return false;
    await ref
        .read(settingsPlaybackProvider.notifier)
        .patch((s) => s.copyWith(p2pAcknowledged: true));
    return true;
  }

  bool _isEnabled({
    required SettingsPlaybackSnapshot? snap,
    required SettingsVisibility visibility,
    required bool debridEnabled,
  }) {
    return switch (widget.addonId) {
      SettingsAddonId.torrent => snap?.playSourceTorrent ?? false,
      SettingsAddonId.stremio => snap?.playSourceStremio ?? false,
      SettingsAddonId.nuvio => snap?.playSourceNuvio ?? false,
      SettingsAddonId.debrid => debridEnabled,
      SettingsAddonId.iptv => visibility.iptvNav,
      SettingsAddonId.liveSports => visibility.liveMatchesNav,
      SettingsAddonId.lan => _lanEnabled,
      _ => false,
    };
  }

  Future<void> _toggle(bool val) async {
    if (_busy) return;
    _busy = true;
    setState(() => _optimisticEnabled = val);
    final notifier = ref.read(settingsPlaybackProvider.notifier);

    try {
      if (val &&
          (widget.addonId == SettingsAddonId.torrent ||
              widget.addonId == SettingsAddonId.stremio ||
              widget.addonId == SettingsAddonId.nuvio)) {
        final ok = await _confirmP2pIfNeeded();
        if (!ok || !mounted) {
          setState(() => _optimisticEnabled = null);
          return;
        }
      }

      switch (widget.addonId) {
        case SettingsAddonId.torrent:
          await _settings.setPlaySourceTorrentEnabled(val);
          await notifier.patch((s) => s.copyWith(playSourceTorrent: val));
        case SettingsAddonId.stremio:
          await _settings.setPlaySourceStremioEnabled(val);
          await notifier.patch((s) => s.copyWith(playSourceStremio: val));
        case SettingsAddonId.nuvio:
          await _settings.setPlaySourceNuvioEnabled(val);
          await notifier.patch((s) => s.copyWith(playSourceNuvio: val));
        case SettingsAddonId.debrid:
          await _settings.setUseDebridForStreams(val);
          ref
              .read(settingsDebridProvider.notifier)
              .patch((s) => s.copyWith(useDebrid: val));
        case SettingsAddonId.iptv:
          await _toggleNavTab('iptv', val);
          if (!val) {
            await notifier.patch((s) => s.copyWith(iptvEpgEnabled: false));
          }
        case SettingsAddonId.liveSports:
          await _toggleNavTab('live_matches', val);
        case SettingsAddonId.lan:
          await LanPrefs.instance.setLanServerEnabled(val);
          if (mounted) setState(() => _lanEnabled = val);
      }
      if (!val) {
        await deactivateAddonChildren(widget.addonId);
      }
      // IPTV / Live Sports are navbar tabs — must push `_domainNavigation` or
      // cloud pull restores the old visibleIds (issue 126 shrink guard).
      // Do not await the upsert here: a slow merge pull blocked the UI and
      // raced soft pulls; gen bumps synchronously at schedulePush start (224).
      if (widget.addonId == SettingsAddonId.iptv ||
          widget.addonId == SettingsAddonId.liveSports) {
        unawaited(scheduleNavigationSyncPush());
        if (widget.addonId == SettingsAddonId.iptv) {
          schedulePreferencesSyncPush();
        }
      } else {
        schedulePreferencesSyncPush();
      }
      // Navbar notifier already bumped by setNavbarConfig — avoid invalidate
      // flash that remounts this switch mid-toggle.
    } catch (e, st) {
      debugPrint('[AddonToggle] ${widget.addonId} failed: $e\n$st');
      if (mounted) setState(() => _optimisticEnabled = null);
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> _toggleNavTab(String navId, bool val) async {
    // Dirty before KV so Addons soft-pull cannot apply empty cloud mid-write.
    noteNavigationDirty();
    // Exclusive RMW — rapid ATV OK on IPTV then Live Sports must not both
    // read empty and write past each other (issue 224).
    final updated = await _settings.setNavbarTabVisible(navId, val);
    debugPrint(
      '[AddonToggle] navbar $navId → $val (next=$updated)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
    final visAsync = ref.watch(settingsVisibilityProvider);
    // Prefer last resolved data across reload flashes (invalidate → loading).
    final visibility = visAsync.hasValue
        ? visAsync.requireValue
        : widget.visibility;
    final debridAsync = ref.watch(settingsDebridProvider);
    final debridEnabled = debridAsync.hasValue
        ? (debridAsync.requireValue.useDebrid)
        : false;
    final computed = _isEnabled(
      snap: snap,
      visibility: visibility,
      debridEnabled: debridEnabled,
    );
    if (_optimisticEnabled != null && _optimisticEnabled == computed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _optimisticEnabled == computed) {
          setState(() => _optimisticEnabled = null);
        }
      });
    }
    final enabled = _optimisticEnabled ?? computed;
    void flip() {
      debugPrint(
        '[AddonToggle] flip ${widget.addonId} ${enabled ? "ON→OFF" : "OFF→ON"}',
      );
      unawaited(_toggle(!enabled));
    }

    widget.onProvideFlip?.call(flip);

    final switchChrome = ForjaSwitch(
      value: enabled,
      onChanged: null,
      scale: ForjaSwitch.settingsScale,
      emphasized: _chromeActive,
    );

    // Row owns OK — switch is display-only (Addons list parity with Features).
    if (widget.chromeOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IgnorePointer(child: switchChrome),
      );
    }

    // Leanback: separate D-pad focus stop (legacy). Switch is display-only
    // (onChanged null) so Material ActivateIntent cannot swallow Select (224).
    final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;
    if (leanback) {
      return Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              flip();
              return null;
            },
          ),
        },
        child: shellFocusableTap(
          context: context,
          focusNode: widget.focusNode,
          onTap: flip,
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
        onChanged: (v) => unawaited(_toggle(v)),
        scale: ForjaSwitch.settingsScale,
        emphasized: _chromeActive,
      ),
    );
  }
}
