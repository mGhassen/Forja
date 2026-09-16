import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/runtime/actions/portals/portals_panel_view.dart';
import 'package:forja/shared/engine/runtime/actions/portals/portals_providers.dart';
import 'package:forja/shared/player/live/tv_focus.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portals_chip.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';

export 'package:forja/shared/engine/portals/portals_host.dart'
    show
        PortalsHost,
        PortalsChipSummary,
        PortalsInventory,
        PortalHealthTracker,
        PortalsPanelAction;
export 'package:forja/shared/engine/runtime/actions/portals/portals_panel_view.dart'
    show PortalsPanelView;
export 'package:forja/shared/engine/runtime/actions/portals/portals_providers.dart';

/// Thin chrome wire — chip + docked Portals rail. Panel paint is [PortalsPanelView].
/// Services live in [PortalsHost]. Pack layout opts in via `action: portals`.
abstract final class PortalsActionHost {
  PortalsActionHost._();

  static Widget buildPortalsChip(
    BuildContext context,
    WidgetRef ref, {
    required String tabId,
    required String rowId,
    required int itemIndex,
    Map<String, dynamic>? action,
    VoidCallback? onDownEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
  }) {
    double? d(String key) {
      final raw = action?[key];
      return raw is num ? raw.toDouble() : null;
    }

    final width = d('width');
    return _PortalsTopBarChip(
      tabId: tabId.trim(),
      rowId: rowId,
      itemIndex: itemIndex,
      width: width != null && width > 0 ? width : null,
      height: d('height'),
      radius: d('radius'),
      pad: d('pad'),
      fontSize: d('fontSize'),
      iconSize: d('iconSize'),
      chevronSize: d('chevronSize'),
      seatsFontSize: d('seatsFontSize'),
      onDownEdge: onDownEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
    );
  }

  static Widget wrapListBody(
    BuildContext context, {
    required Widget child,
    required String tabId,
    required String sourceId,
    required bool shellTabVisible,
  }) {
    return _PortalsPanelHost(
      tabId: tabId,
      shellTabVisible: shellTabVisible,
      child: child,
    );
  }
}

/// Top-bar Portals chip — hover/focus probes active portal (status + seats).
class _PortalsTopBarChip extends ConsumerStatefulWidget {
  const _PortalsTopBarChip({
    required this.tabId,
    required this.rowId,
    required this.itemIndex,
    this.width,
    this.height,
    this.radius,
    this.pad,
    this.fontSize,
    this.iconSize,
    this.chevronSize,
    this.seatsFontSize,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final String tabId;
  final String rowId;
  final int itemIndex;
  final double? width;
  final double? height;
  final double? radius;
  final double? pad;
  final double? fontSize;
  final double? iconSize;
  final double? chevronSize;
  final double? seatsFontSize;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  ConsumerState<_PortalsTopBarChip> createState() => _PortalsTopBarChipState();
}

class _PortalsTopBarChipState extends ConsumerState<_PortalsTopBarChip> {
  late final PortalHealthTracker _health;
  bool _hovered = false;
  bool _focused = false;
  String _probeKey = '';

  /// Hub open often mounts the chip under the cursor — [MouseRegion] fires
  /// `onEnter` without a real hover. Wait for pointer exit (or first paint
  /// with no hover) before treating enter as intent to probe.
  bool _armHoverProbe = false;

  @override
  void initState() {
    super.initState();
    _health = PortalHealthTracker(onChanged: () {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hovered) {
        _armHoverProbe = false;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _armHoverProbe = !_hovered;
      });
    });
  }

  @override
  void dispose() {
    _health.dispose();
    super.dispose();
  }

  void _onActiveChange({required bool hovered, required bool focused}) {
    final key = _probeKey;
    if (key.isEmpty) return;
    final leanback = liveLeanbackOnly(context);
    // Leanback: focus only. Desktop hybrid: keyboard focus OR intentional hover
    // (mount-under-cursor is gated by [_armHoverProbe]).
    final want = leanback
        ? focused
        : (focused || (hovered && _armHoverProbe));
    if (want) {
      // Soft refresh — keep painted green/red; update when probe lands.
      _health.schedule(key, leanback: leanback, force: true);
    } else {
      _health.cancel(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.tabId;
    final open = ref.watch(portalsPanelOpenProvider(key));
    final summary = ref.watch(portalsChipSummaryProvider(key));
    var label = summary.asData?.value.label ?? 'Portals';
    var hasPortal = summary.asData?.value.hasPortal ?? false;
    var portalKey = summary.asData?.value.portalKey ?? '';
    var seatsUsed = summary.asData?.value.seatsUsed;
    var seatsMax = summary.asData?.value.seatsMax;

    if (open) {
      final inv = ref.watch(portalsInventoryProvider(key));
      final data = inv.asData?.value;
      if (data != null) {
        label = data.activeLabel;
        hasPortal = data.portals.isNotEmpty;
        final active = data.activeKey.trim();
        if (active.isNotEmpty) {
          portalKey = active;
        } else {
          for (final p in data.portals) {
            if (!p.selected) continue;
            portalKey = p.id;
            break;
          }
        }
        for (final p in data.portals) {
          if (p.id != portalKey) continue;
          seatsUsed = p.activeConnections;
          seatsMax = p.maxConnections;
          break;
        }
      }
    }

    if (portalKey != _probeKey) {
      if (_probeKey.isNotEmpty) _health.cancel(_probeKey);
      _probeKey = portalKey;
      // Hub open / active portal change: preload chip status now (TTL still
      // applies). Keep `_armHoverProbe` for intentional hover — mount-under-
      // cursor must not cancel this via `_onActiveChange(want: false)`.
      if (portalKey.isNotEmpty) {
        final probeKey = portalKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _probeKey != probeKey) return;
          _health.schedule(
            probeKey,
            leanback: liveLeanbackOnly(context),
            immediate: true,
          );
        });
      }
    }

    final painted = portalKey.isEmpty
        ? null
        : _health.paint(
            PortalListItem(
              id: portalKey,
              label: label,
              selected: false,
              healthy: null,
              checking: false,
              activeConnections: seatsUsed ?? '',
              maxConnections: seatsMax ?? '',
            ),
          );
    final checking = painted?.checking ?? false;
    final healthy = painted?.healthy;
    final used = (painted?.activeConnections ?? seatsUsed ?? '').trim();
    final max = (painted?.maxConnections ?? seatsMax ?? '').trim();

    final policy = ShellScope.inputPolicyOf(context);
    return PortalsChip(
      label: label,
      hasPortal: hasPortal,
      selected: open,
      checking: checking,
      healthy: healthy,
      seatsUsed: used.isEmpty ? null : used,
      seatsMax: max.isEmpty ? null : max,
      width: widget.width,
      height: widget.height ?? 40,
      radius: widget.radius ?? 8,
      pad: widget.pad,
      fontSize: widget.fontSize ?? 12.5,
      iconSize: widget.iconSize ?? 16,
      chevronSize: widget.chevronSize ?? 18,
      seatsFontSize: widget.seatsFontSize ?? 12,
      tvFocus: policy.useFocusableMoodChips,
      onTap: () {
        final opening = !open;
        ref.read(portalsPanelOpenProvider(key).notifier).state = opening;
        if (opening) {
          preparePortalsPanel(ProviderScope.containerOf(context), key);
        }
      },
      onFocusChange: (focused) {
        _focused = focused;
        _onActiveChange(hovered: _hovered, focused: focused);
      },
      onHoverChange: (hovered) {
        if (!hovered) {
          _hovered = false;
          _armHoverProbe = true;
          _onActiveChange(hovered: false, focused: _focused);
          return;
        }
        _hovered = true;
        _onActiveChange(hovered: true, focused: _focused);
      },
      interactiveBuilder: ({
        required child,
        required onTap,
        onFocusChange,
        onHoverChange,
      }) =>
          shellFocusableTap(
            context: context,
            onTap: onTap,
            borderRadius: 8,
            scaleOnFocus: 1.0,
            tvZone: ShellTvZone.topBar,
            tvTabId: widget.tabId,
            tvRowId: widget.rowId,
            tvItemIndex: widget.itemIndex,
            onLeftEdge: widget.onLeftEdge,
            onRightEdge: widget.onRightEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: onFocusChange,
            onHoverChange: onHoverChange,
            child: child,
          ),
    );
  }
}

/// Back-compat alias — prefer [PortalsHost.resolvePluginId].
Future<String?> resolvePortalsPluginId({String? preferTabId}) =>
    PortalsHost.resolvePluginId(preferTabId: preferTabId);

class _PortalsPanelHost extends ConsumerStatefulWidget {
  const _PortalsPanelHost({
    required this.child,
    required this.tabId,
    required this.shellTabVisible,
  });

  final Widget child;
  final String tabId;
  final bool shellTabVisible;

  @override
  ConsumerState<_PortalsPanelHost> createState() => _PortalsPanelHostState();
}

class _PortalsPanelHostState extends ConsumerState<_PortalsPanelHost> {
  static const _fallbackWidth = 380.0;

  /// Matches v1.5.36: soft-pull cloud assignments when the IPTV hub is shown,
  /// not only when the Portals chip is tapped.
  bool _prepared = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.shellTabVisible) {
      _prepared = false;
      return widget.child;
    }
    final key = widget.tabId.trim();
    if (!_prepared && key.isNotEmpty) {
      _prepared = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.shellTabVisible) return;
        preparePortalsPanel(ProviderScope.containerOf(context), key);
      });
    }
    final open = ref.watch(portalsPanelOpenProvider(key));
    final inv =
        open ? ref.watch(portalsInventoryProvider(key)).asData?.value : null;
    final width = (inv?.width ?? _fallbackWidth);
    return SidePanelOverlay(
      open: open,
      panelWidth: width,
      onDismiss: () {
        ref.read(portalsPanelOpenProvider(key).notifier).state = false;
      },
      panel: open
          ? PortalsPanelView(
              tabId: key,
              width: width,
              onClose: () {
                ref.read(portalsPanelOpenProvider(key).notifier).state = false;
              },
            )
          : const SizedBox.shrink(),
      child: widget.child,
    );
  }
}
