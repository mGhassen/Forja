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
  });

  final String addonId;
  final SettingsVisibility visibility;

  /// TV: owned by the parent row so → / ← can move row ↔ switch.
  final FocusNode? focusNode;

  /// TV: ← from the switch returns to the addon row.
  final VoidCallback? onLeftEdge;

  @override
  ConsumerState<AddonMasterToggle> createState() => _AddonMasterToggleState();
}

class _AddonMasterToggleState extends ConsumerState<AddonMasterToggle> {
  final SettingsService _settings = SettingsService();
  bool _lanEnabled = false;
  bool _focused = false;
  bool _hovered = false;

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

  bool _isEnabled(SettingsPlaybackSnapshot? snap) {
    return switch (widget.addonId) {
      SettingsAddonId.torrent => snap?.playSourceTorrent ?? false,
      SettingsAddonId.stremio => snap?.playSourceStremio ?? false,
      SettingsAddonId.nuvio => snap?.playSourceNuvio ?? false,
      SettingsAddonId.debrid =>
        ref.read(settingsDebridProvider).valueOrNull?.useDebrid ?? false,
      SettingsAddonId.iptv => widget.visibility.iptvNav,
      SettingsAddonId.liveSports => widget.visibility.liveMatchesNav,
      SettingsAddonId.lan => _lanEnabled,
      _ => false,
    };
  }

  Future<void> _toggle(bool val) async {
    final notifier = ref.read(settingsPlaybackProvider.notifier);

    if (val &&
        (widget.addonId == SettingsAddonId.torrent ||
            widget.addonId == SettingsAddonId.stremio ||
            widget.addonId == SettingsAddonId.nuvio)) {
      final ok = await _confirmP2pIfNeeded();
      if (!ok || !mounted) return;
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
        setState(() => _lanEnabled = val);
    }
    if (!val) {
      await deactivateAddonChildren(widget.addonId);
    }
    // IPTV / Live Sports are navbar tabs — must push `_domainNavigation` or
    // cloud pull restores the old visibleIds (issue 126 shrink guard).
    if (widget.addonId == SettingsAddonId.iptv ||
        widget.addonId == SettingsAddonId.liveSports) {
      scheduleNavigationSyncPush();
      if (widget.addonId == SettingsAddonId.iptv) {
        schedulePreferencesSyncPush();
      }
    } else {
      schedulePreferencesSyncPush();
    }
    ref.invalidate(settingsVisibilityProvider);
  }

  Future<void> _toggleNavTab(String navId, bool val) async {
    final nav = await _settings.getNavbarConfig();
    final updated = val
        ? [...nav, if (!nav.contains(navId)) navId]
        : nav.where((id) => id != navId).toList();
    await _settings.setNavbarConfig(updated);
    ref.invalidate(settingsVisibilityProvider);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
    final enabled = _isEnabled(snap);
    void flip() => unawaited(_toggle(!enabled));
    // IgnorePointer so the row/focus wrapper owns taps — pass [emphasized]
    // because Theme cannot override ForjaSwitch's hardcoded thumbColor.
    final switchVisual = IgnorePointer(
      child: ForjaSwitch(
        value: enabled,
        onChanged: (_) {},
        scale: ForjaSwitch.settingsScale,
        emphasized: _chromeActive,
      ),
    );
    // Desktop hybrid + TV: focus stop so → from the addon row lands here.
    // Pure touch: opaque tap on the switch only (row opens detail).
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (tv) {
      return shellFocusableTap(
        context: context,
        focusNode: widget.focusNode,
        onTap: flip,
        borderRadius: 20,
        scaleOnFocus: 1.0,
        showFocusRail: false,
        showFocusFill: false,
        showFocusBorder: false,
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
        // Stable focus rect — tiny scaled Switch alone loses spatial →.
        child: SizedBox(
          width: 52,
          height: 40,
          child: Center(child: switchVisual),
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: flip,
        child: switchVisual,
      ),
    );
  }
}
