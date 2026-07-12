import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/design/design.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_search_bar.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/features/iptv/iptv/data/hardcoded_channels.dart';
import 'package:forja/features/iptv/iptv/data/iptv_portal_share.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_playlists_screen.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_catalog_workspace.dart';
import 'iptv_pt_player_screen.dart';

/// Mask a URL for safe display: keeps host, masks each path segment to first 2 chars + ***.
/// Returns '—' for empty/invalid input. Strips query and fragment.
String _redactUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '—';
  return url.trim();
}

/// Main entry-point widget for the PT IPTV experience.
/// Presents all 6 sub-views and routes to the dedicated player.
class IptvPtScreen extends StatefulWidget {
  const IptvPtScreen({super.key});

  @override
  State<IptvPtScreen> createState() => _IptvPtScreenState();
}

class _IptvPtScreenState extends State<IptvPtScreen>
    with ShellTabRefresh<IptvPtScreen> {
  late final IptvController _ctrl;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleIptv;

  @override
  bool get shellBlocksEviction =>
      _ctrl.view == IptvView.episodeList || _ctrl.activePortal != null;

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    await _ctrl.init();
  }

  @override
  void initState() {
    super.initState();
    _ctrl = IptvController();
    _ctrl.addListener(_syncShellNav);
    _ctrl.init().then((_) {
      if (mounted) markShellTabFresh();
    });
  }

  void _syncShellNav() {
    final hide = _ctrl.view == IptvView.episodeList;
    if (ShellBus.hideGlobalNav.value != hide) {
      ShellBus.hideGlobalNav.value = hide;
      ShellBus.notifyShellChromeChanged();
    }
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('iptv');
    _ctrl.removeListener(_syncShellNav);
    _ctrl.dispose();
    super.dispose();
  }

  bool _isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < 720;
  bool _isWide(BuildContext c) => shellIptvUsesWideLayout(c);

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('iptv_pt_screen'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0) _syncShellNav();
      },
      child: PopScope(
        canPop: !_ctrl.portalPanelOpen && _ctrl.view != IptvView.episodeList,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _ctrl.back();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(_ctrl.view),
              child: _buildView(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildView(BuildContext context) {
    switch (_ctrl.view) {
      case IptvView.portalList:
      case IptvView.sectionPick:
      case IptvView.browser:
        return _IptvCatalogShell(
          ctrl: _ctrl,
          compact: _isCompact(context),
          wide: _isWide(context),
        );
      case IptvView.episodeList:
        return _EpisodeListView(ctrl: _ctrl, compact: _isCompact(context));
      case IptvView.channelsHub:
      case IptvView.channelResults:
        return _IptvCatalogShell(
          ctrl: _ctrl,
          compact: _isCompact(context),
          wide: _isWide(context),
        );
    }
  }
}

class _IptvCatalogShell extends StatelessWidget {
  const _IptvCatalogShell({
    required this.ctrl,
    required this.compact,
    required this.wide,
  });

  final IptvController ctrl;
  final bool compact;
  final bool wide;

  static const double _panelWidth = 380;

  bool _useSidePanel(BuildContext context) =>
      wide || ShellTokens.isAndroidTvDevice || !compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IptvCatalogTopBar(
          ctrl: ctrl,
          onTogglePanel: ctrl.togglePortalPanel,
          onSection: ctrl.requestSection,
        ),
        Expanded(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _BrowserView(
                      ctrl: ctrl,
                      compact: compact,
                      wide: wide,
                      embedded: true,
                    ),
                  ),
                  if (ctrl.portalPanelOpen && _useSidePanel(context))
                    IptvPortalPanel(
                      ctrl: ctrl,
                      width: _panelWidth,
                      onClose: ctrl.closePortalPanel,
                    ),
                ],
              ),
              if (ctrl.portalPanelOpen && !_useSidePanel(context))
                Positioned.fill(
                  child: GestureDetector(
                    onTap: ctrl.closePortalPanel,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: IptvPortalPanel(
                            ctrl: ctrl,
                            width: MediaQuery.sizeOf(context).width * 0.92,
                            onClose: ctrl.closePortalPanel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Common widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PtAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  const _PtAppBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null) iptvBackButton(context, onTap: onBack),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 28),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final String tag;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final int? listIndex;
  const _SourceChip({
    required this.label,
    required this.tag,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? IptvShellStyle.chipSelectedBg
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: iptvTap(
            context: context,
            onTap: enabled ? onTap : null,
            borderRadius: 12,
            listIndex: listIndex,
            tvRowId: 'portal-sources',
            tvItemIndex: listIndex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tag,
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : IptvShellStyle.accent,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PORTAL LIST VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _PortalListView extends StatelessWidget {
  final IptvController ctrl;
  final bool compact;
  const _PortalListView({required this.ctrl, required this.compact});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _PtAppBar(
            title: 'IPTV Portals',
            subtitle: ctrl.statusText.isEmpty
                ? '${ctrl.verified.length} verified'
                : ctrl.statusText,
            actions: [
              IptvIconAction(
                tooltip: 'M3U Playlists',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const M3uPlaylistsScreen()),
                ),
                icon: Icons.playlist_play_rounded,
              ),
              IptvIconAction(
                tooltip: 'Add portal',
                onPressed: () => _showAddDialog(context),
                icon: Icons.add_rounded,
              ),
              if (ctrl.verified.isNotEmpty)
                IptvIconAction(
                  tooltip: ctrl.editMode ? 'Done' : 'Edit',
                  onPressed: ctrl.toggleEditMode,
                  icon: ctrl.editMode
                      ? Icons.check_rounded
                      : Icons.edit_rounded,
                  color: ctrl.editMode ? IptvShellStyle.accent : Colors.white70,
                ),
            ],
          ),
          if (ctrl.editMode && ctrl.verified.isNotEmpty) _buildEditBar(),
          Expanded(
            child: ctrl.verified.isEmpty
                ? _buildEmpty(context)
                : _buildPortalGrid(),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildEditBar() {
    final allSelected = ctrl.selected.length == ctrl.verified.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: IptvShellStyle.chipSelectedBg.withValues(alpha: 0.35),
      child: Row(
        children: [
          IptvTextAction(
            icon: allSelected ? Icons.deselect : Icons.select_all,
            label: allSelected ? 'Clear' : 'All',
            onPressed: ctrl.toggleSelectAll,
          ),
          const Spacer(),
          Text(
            '${ctrl.selected.length} selected',
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          const SizedBox(width: 12),
          IptvIconAction(
            tooltip: 'Delete selected',
            onPressed: ctrl.selected.isEmpty
                ? null
                : () => ctrl.deleteSelected(),
            icon: Icons.delete_rounded,
            color: ctrl.selected.isEmpty
                ? Colors.white24
                : const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.satellite_alt_rounded,
                    size: 80,
                    color: IptvShellStyle.accent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No portals yet',
                    style: IptvShellStyle.pageTitle.copyWith(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ctrl.statusText.isEmpty
                        ? 'Find live Xtream portals,\nor add one manually.'
                        : ctrl.statusText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  IptvPrimaryButton(
                    icon: ctrl.isScraping
                        ? Icons.stop_circle_rounded
                        : Icons.travel_explore,
                    label: ctrl.isScraping ? 'Stop' : 'Find Portals',
                    onPressed: ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortalGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        final cross = (c.maxWidth ~/ 320).clamp(1, 4);
        final count = ctrl.verified.length;
        iptvSyncRow(rowId: 'portals', sortOrder: 0, itemCount: count);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 120,
          ),
          itemCount: count,
          itemBuilder: (_, i) {
            final v = ctrl.verified[i];
            final selected = ctrl.selected.contains(v.key);
            return _PortalCard(
              v: v,
              editMode: ctrl.editMode,
              selected: selected,
              isFavorite: ctrl.isFavoritePortal(v.key),
              gridIndex: i,
              gridColumns: cross,
              onToggleFavorite: () => ctrl.toggleFavoritePortal(v.key),
              onTap: () {
                if (ctrl.editMode) {
                  ctrl.toggleSelect(v.key);
                } else {
                  ctrl.openPortal(v);
                }
              },
              onLongPress: () {
                if (!ctrl.editMode) {
                  ctrl.toggleEditMode();
                  ctrl.toggleSelect(v.key);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final actions =
        <({IconData icon, String label, bool subtle, VoidCallback? onPressed})>[
          (
            icon: ctrl.isScraping
                ? Icons.stop_circle_rounded
                : Icons.travel_explore,
            label: ctrl.isScraping ? 'Stop' : 'Scrape',
            subtle: false,
            onPressed: ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
          ),
          if (ctrl.canGetMore)
            (
              icon: Icons.add_circle_outline,
              label: 'Get More',
              subtle: true,
              onPressed: ctrl.isScraping ? null : ctrl.getMore,
            ),
          (
            icon: Icons.tv_rounded,
            label: 'Channels',
            subtle: true,
            onPressed: ctrl.openChannelsHub,
          ),
          if (ctrl.verified.isNotEmpty)
            (
              icon: Icons.refresh_rounded,
              label: 'Re-verify',
              subtle: true,
              onPressed: ctrl.runVerification,
            ),
        ];
    iptvSyncRow(
      rowId: 'portal-actions',
      sortOrder: 2,
      itemCount: actions.length,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  IptvPrimaryButton(
                    icon: actions[i].icon,
                    label: actions[i].label,
                    subtle: actions[i].subtle,
                    onPressed: actions[i].onPressed,
                    tvRowId: 'portal-actions',
                    tvItemIndex: i,
                  ),
                  if (i < actions.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => ShellScope.rehost(
        context,
        AnimatedBuilder(
          animation: ctrl,
          builder: (_, _) => AlertDialog(
            backgroundColor: IptvShellStyle.surface,
            title: Text(
              'Add Portal',
              style: IptvShellStyle.pageTitle.copyWith(fontSize: 26),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _input(
                    urlCtrl,
                    'http://portal.example.com:8080',
                    'Portal URL',
                  ),
                  const SizedBox(height: 8),
                  _input(userCtrl, 'username', 'Username'),
                  const SizedBox(height: 8),
                  _input(passCtrl, 'password', 'Password', obscure: true),
                  if (ctrl.addError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      ctrl.addError!,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              IptvTextAction(
                icon: Icons.close_rounded,
                label: 'Cancel',
                color: Colors.white70,
                onPressed: ctrl.isAdding
                    ? null
                    : () {
                        ctrl.dismissAddDialog();
                        Navigator.of(ctx).pop();
                      },
              ),
              IptvPrimaryButton(
                icon: Icons.add_rounded,
                label: ctrl.isAdding ? 'Adding…' : 'Add',
                busy: ctrl.isAdding,
                onPressed: ctrl.isAdding
                    ? null
                    : () async {
                        await ctrl.addManual(
                          url: urlCtrl.text,
                          username: userCtrl.text,
                          password: passCtrl.text,
                        );
                        if (ctrl.addError == null && ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String hint,
    String label, {
    bool obscure = false,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final VerifiedPortal v;
  final bool editMode;
  final bool selected;
  final bool isFavorite;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;
  const _PortalCard({
    required this.v,
    required this.editMode,
    required this.selected,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
    this.gridIndex,
    this.gridColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: IptvShellStyle.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? IptvShellStyle.accent
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 14,
          gridIndex: gridIndex,
          gridColumns: gridColumns,
          tvRowId: 'portals',
          tvZone: ShellTvZone.grid,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (editMode) ...[
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: selected ? IptvShellStyle.accent : Colors.white30,
                  ),
                  const SizedBox(width: 12),
                ] else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: IptvShellStyle.chipSelectedBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tv_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _displayName(v),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _redactUrl(v.portal.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _Pill(
                            icon: Icons.event_rounded,
                            label: v.expiry,
                            color: const Color(0xFFA855F7),
                          ),
                          const SizedBox(width: 6),
                          _Pill(
                            icon: Icons.people_rounded,
                            label: '${v.activeConnections}/${v.maxConnections}',
                            color: const Color(0xFF22C55E),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!editMode) ...[
                  IptvIconAction(
                    tooltip: 'Copy share code',
                    onPressed: () async {
                      try {
                        final code =
                            await IptvPortalShare.createShare(v.portal);
                        await Clipboard.setData(ClipboardData(text: code));
                        ForjaToast.success(
                          'Share code copied: $code',
                          duration: const Duration(seconds: 3),
                        );
                      } catch (_) {
                        ForjaToast.error('Could not create share code');
                      }
                    },
                    icon: Icons.copy_rounded,
                    color: Colors.white54,
                    iconSize: 20,
                  ),
                  IptvIconAction(
                    tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
                    onPressed: onToggleFavorite,
                    icon: isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: isFavorite
                        ? const Color(0xFFFACC15)
                        : Colors.white38,
                    iconSize: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show a friendly name; if the portal had no name we fall back to a
  /// redacted form of its URL so we never leak host paths in the UI.
  static String _displayName(VerifiedPortal v) {
    final n = v.name.trim();
    if (n.isEmpty) return _redactUrl(v.portal.url);
    if (n.startsWith('http://') || n.startsWith('https://')) {
      return _redactUrl(n);
    }
    return n;
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION PICK
// ─────────────────────────────────────────────────────────────────────────────
class _SectionPickView extends StatelessWidget {
  final IptvController ctrl;
  final bool compact;
  const _SectionPickView({required this.ctrl, required this.compact});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _PtAppBar(
            title: ctrl.activePortal?.name ?? 'Portal',
            subtitle: _redactUrl(ctrl.activePortal?.portal.url),
            onBack: ctrl.back,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                final cross = c.maxWidth >= 800
                    ? 3
                    : (c.maxWidth >= 520 ? 3 : 1);
                const sections = 3;
                iptvSyncRow(
                  rowId: 'section-pick',
                  sortOrder: 0,
                  itemCount: sections,
                );
                return GridView.count(
                  padding: const EdgeInsets.all(20),
                  crossAxisCount: cross,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: cross == 1 ? 2.6 : 1.1,
                  children: [
                    _SectionTile(
                      icon: Icons.live_tv_rounded,
                      label: 'Live TV',
                      colors: const [Color(0xFFEF4444), Color(0xFF7C2D12)],
                      gridIndex: 0,
                      gridColumns: cross,
                      onTap: () => ctrl.openSection(IptvSection.live),
                    ),
                    _SectionTile(
                      icon: Icons.movie_rounded,
                      label: 'Movies',
                      colors: const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                      gridIndex: 1,
                      gridColumns: cross,
                      onTap: () => ctrl.openSection(IptvSection.vod),
                    ),
                    _SectionTile(
                      icon: Icons.video_library_rounded,
                      label: 'Series',
                      colors: const [Color(0xFF374151), Color(0xFF1CE783)],
                      gridIndex: 2,
                      gridColumns: cross,
                      onTap: () => ctrl.openSection(IptvSection.series),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback onTap;
  const _SectionTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 20,
          gridIndex: gridIndex,
          gridColumns: gridColumns,
          tvRowId: 'section-pick',
          tvZone: ShellTvZone.grid,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 56),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BROWSER (Live / VOD / Series listing)
// ─────────────────────────────────────────────────────────────────────────────
class _BrowserView extends StatefulWidget {
  final IptvController ctrl;
  final bool compact;
  final bool wide;
  final bool embedded;
  const _BrowserView({
    required this.ctrl,
    required this.compact,
    required this.wide,
    this.embedded = false,
  });

  @override
  State<_BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<_BrowserView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _openPortalFocus = FocusNode(debugLabel: 'iptv-open-portal');
  Timer? _scrollSettleTimer;
  bool _didInitialFocus = false;
  bool _wasLoading = false;

  bool get _searchOpen => widget.ctrl.browserSearchOpen;
  bool get _needsPortal => widget.ctrl.activePortal == null;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.ctrl.browserSearch;
    _wasLoading = widget.ctrl.isLoading;
    widget.ctrl.addListener(_onCtrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncInitialFocus());
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChanged);
    _scrollSettleTimer?.cancel();
    _searchFocus.dispose();
    _openPortalFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    if (!mounted) return;
    final loading = widget.ctrl.isLoading;
    final finishedLoad = _wasLoading && !loading;
    _wasLoading = loading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_needsPortal) {
        // Don't steal focus while the portals panel is open.
        if (!widget.ctrl.portalPanelOpen && !_openPortalFocus.hasFocus) {
          _focusOpenPortalButton();
        }
        return;
      }
      if (loading) return;
      if (finishedLoad || !_didInitialFocus) {
        if (widget.ctrl.categories.isNotEmpty ||
            widget.ctrl.browserAllStreams.isNotEmpty) {
          _focusCatalogGroup();
        }
      }
    });
  }

  void _syncInitialFocus() {
    if (!mounted) return;
    if (_needsPortal) {
      _focusOpenPortalButton();
    } else if (!widget.ctrl.isLoading) {
      _focusCatalogGroup();
    }
  }

  void _focusOpenPortalButton() {
    if (!_openPortalFocus.canRequestFocus) return;
    _openPortalFocus.requestFocus();
    _didInitialFocus = false;
  }

  void _focusCatalogGroup() {
    final focused = (widget.wide || widget.compact)
        ? iptvFocusRowItem('browser-categories', 0)
        : iptvFocusRowItem('browser-category-chips', 0);
    if (!focused) {
      iptvFocusRowItem('browser-streams', 0);
    }
    _didInitialFocus = true;
  }

  @override
  void didUpdateWidget(covariant _BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ctrl.browserSearchOpen && !oldWidget.ctrl.browserSearchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
    if (!widget.ctrl.browserSearchOpen && _searchCtrl.text.isNotEmpty) {
      _searchCtrl.clear();
    }
  }

  void _openSearch() {
    widget.ctrl.openBrowserSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    widget.ctrl.closeBrowserSearch();
    _searchCtrl.clear();
    _searchFocus.unfocus();
    if (mounted) setState(() {});
  }

  void _clearSearchQuery() {
    _searchCtrl.clear();
    widget.ctrl.setBrowserSearch('');
    if (mounted) setState(() {});
  }

  void toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  void _toggleSearch() => toggleSearch();

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _scrollSettleTimer?.cancel();
      widget.ctrl.cancelAllLazyChecks();
    } else if (n is ScrollEndNotification) {
      _scrollSettleTimer?.cancel();
      _scrollSettleTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() {});
      });
    }
    return false;
  }

  String get _sectionTitle {
    switch (widget.ctrl.activeSection) {
      case IptvSection.live:
        return 'Live TV';
      case IptvSection.vod:
        return 'Movies';
      case IptvSection.series:
        return 'Series';
      default:
        return 'Browse';
    }
  }

  /// Categories visible in the sidebar/chips. When the user types a query,
  /// hide categories whose name doesn't match — but always keep the currently
  /// selected one so the UI never shows an empty selection.
  List<IptvCategory> get _filteredCategories {
    final ctrl = widget.ctrl;
    final q = ctrl.browserSearch.trim().toLowerCase();
    if (q.isEmpty) return ctrl.categories;
    final selected = ctrl.browserSelectedCategoryId;
    return ctrl.categories.where((c) {
      if (c.id == selected) return true;
      // 'All' (id == '') is always useful while searching globally
      if (c.id.isEmpty) return true;
      return c.name.toLowerCase().contains(q);
    }).toList();
  }

  List<IptvStream> get _filteredStreams {
    final ctrl = widget.ctrl;
    var s = ctrl.browserAllStreams;
    final cat = ctrl.browserSelectedCategoryId;
    final q = ctrl.browserSearch.trim().toLowerCase();

    if (q.isNotEmpty) {
      // Search is global across categories AND matches by stream name OR by
      // the stream's category name. Lookup table built once per filter pass.
      final catNameById = <String, String>{
        for (final c in ctrl.categories) c.id: c.name.toLowerCase(),
      };
      s = s.where((x) {
        if (x.name.toLowerCase().contains(q)) return true;
        final cn = catNameById[x.categoryId];
        return cn != null && cn.contains(q);
      }).toList();
    } else if (cat != null && cat.isNotEmpty) {
      s = s.where((x) => x.categoryId == cat).toList();
    }

    if (ctrl.activeSection == IptvSection.live &&
        ctrl.liveOnly &&
        ctrl.aliveStreamIds.isNotEmpty) {
      s = s.where((x) => ctrl.aliveStreamIds.contains(x.streamId)).toList();
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    if (ctrl.activePortal == null) {
      return _buildChoosePortalEmpty(context);
    }

    final body = Column(
      children: [
        if (!widget.embedded)
          _PtAppBar(
            title: _sectionTitle,
            subtitle: ctrl.activePortal?.name,
            onBack: ctrl.back,
            actions: [
              IptvIconAction(
                tooltip: _searchOpen ? 'Close search' : 'Search channels',
                onPressed: _toggleSearch,
                icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: _searchOpen ? IptvShellStyle.accent : null,
              ),
              if (ctrl.activeSection == IptvSection.live) ...[
                IptvIconAction(
                  tooltip: 'Reload channels',
                  onPressed: ctrl.isLoading
                      ? null
                      : () => ctrl.openSection(IptvSection.live),
                  icon: Icons.refresh_rounded,
                ),
                IptvIconAction(
                  tooltip: ctrl.isVerifyingAlive
                      ? 'Stop alive check'
                      : 'Re-check all streams',
                  onPressed: ctrl.isVerifyingAlive
                      ? ctrl.stopAliveCheck
                      : ctrl.recheckAlive,
                  icon: ctrl.isVerifyingAlive
                      ? Icons.stop_circle_rounded
                      : Icons.verified_outlined,
                ),
              ],
            ],
          ),
        if (!widget.embedded)
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _searchOpen ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: _buildOverlaySearchBar(),
            ),
          ),
        if (ctrl.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              ctrl.error!,
              style: GoogleFonts.poppins(color: const Color(0xFFEF4444)),
            ),
          ),
        Expanded(
          child: ctrl.isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: IptvShellStyle.accent,
                  ),
                )
              : _buildContent(),
        ),
      ],
    );

    if (widget.embedded) return body;
    return SafeArea(child: body);
  }

  Widget _buildChoosePortalEmpty(BuildContext context) {
    iptvSyncRow(rowId: 'iptv-open-portal', sortOrder: 0, itemCount: 1);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.satellite_alt_rounded,
              size: 72,
              color: IptvShellStyle.accent,
            ),
            const SizedBox(height: 20),
            Text(
              'Choose a portal',
              style: IptvShellStyle.pageTitle.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a provider to browse Live TV, Movies, and Series.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 28),
            IptvPrimaryButton(
              icon: Icons.dns_rounded,
              label: 'Open portal',
              focusNode: _openPortalFocus,
              tvRowId: 'iptv-open-portal',
              tvItemIndex: 0,
              onPressed: widget.ctrl.openPortalPanel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlaySearchBar() {
    final query = widget.ctrl.browserSearch;
    return ShellSearchBar(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      query: query,
      wrapSafeArea: false,
      hintText: 'Search channels or categories…',
      onChanged: widget.ctrl.setBrowserSearch,
      onClear: _clearSearchQuery,
      onEscape: _closeSearch,
      clearSuffix: query.isNotEmpty
          ? iptvCloseButton(context, onTap: _clearSearchQuery)
          : null,
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final categoryWidth = widget.compact
            ? (constraints.maxWidth * 0.34).clamp(132.0, 184.0)
            : (widget.wide ? 240.0 : 200.0);

        return Row(
          children: [
            SizedBox(
              width: categoryWidth,
              child: _buildCategorySidebar(compact: widget.compact),
            ),
            Expanded(
              child: widget.compact ? _buildStreamRows() : _buildStreamGrid(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySidebar({bool compact = false}) {
    final ctrl = widget.ctrl;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Builder(
        builder: (_) {
          final cats = _filteredCategories;
          iptvSyncRow(
            rowId: 'browser-categories',
            sortOrder: 2,
            itemCount: cats.length,
            orientation: ShellTvRowOrientation.vertical,
            onFocusUp: () => iptvFocusRowItem('iptv-sections'),
          );
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: cats.length,
            itemBuilder: (_, i) {
              final c = cats[i];
              final selected = c.id == ctrl.browserSelectedCategoryId;
              return iptvTap(
                context: context,
                onTap: () => ctrl.selectBrowserCategory(c.id),
                borderRadius: 8,
                listIndex: i,
                tvRowId: 'browser-categories',
                tvItemIndex: i,
                onUpEdge: i == 0
                    ? () => iptvFocusRowItem('iptv-sections')
                    : null,
                onRightEdge: () => iptvFocusRowItem('browser-streams'),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: compact ? 9 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? IptvShellStyle.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: selected
                            ? IptvShellStyle.accent
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    c.name.isEmpty ? 'Uncategorized' : c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: compact ? 11 : 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStreamGrid() {
    final ctrl = widget.ctrl;
    final list = _filteredStreams;
    if (list.isEmpty) {
      return _buildStreamsEmpty();
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final cross = (c.maxWidth ~/ 180).clamp(2, 8);
        iptvSyncRow(
          rowId: 'browser-streams',
          sortOrder: 3,
          itemCount: list.length,
          onFocusUp: () {
            if (widget.wide || widget.compact) {
              iptvFocusRowItem('browser-categories');
            } else {
              iptvFocusRowItem('browser-category-chips');
            }
          },
        );
        final cats = _filteredCategories;
        final selectedCatIdx = cats.indexWhere(
          (cat) => cat.id == ctrl.browserSelectedCategoryId,
        );
        final grid = GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => _StreamCard(
            stream: list[i],
            ctrl: widget.ctrl,
            gridIndex: i,
            gridColumns: cross,
            onUpEdge: i < cross
                ? () {
                    if (widget.wide || widget.compact) {
                      iptvFocusRowItem(
                        'browser-categories',
                        selectedCatIdx >= 0 ? selectedCatIdx : 0,
                      );
                    } else {
                      iptvFocusRowItem('browser-category-chips');
                    }
                  }
                : null,
            onLeftEdge: (widget.wide || widget.compact) && i % cross == 0
                ? () => iptvFocusRowItem(
                    'browser-categories',
                    selectedCatIdx >= 0 ? selectedCatIdx : 0,
                  )
                : null,
            onTap: () => _onStreamTap(list[i]),
          ),
        );
        if (!_LiveHealthProbe.usesScrollDebounce(ctx)) return grid;
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: grid,
        );
      },
    );
  }

  Widget _buildStreamRows() {
    final ctrl = widget.ctrl;
    final list = _filteredStreams;
    if (list.isEmpty) return _buildStreamsEmpty();

    final cats = _filteredCategories;
    final selectedCatIdx = cats.indexWhere(
      (cat) => cat.id == ctrl.browserSelectedCategoryId,
    );
    final categoryNames = {for (final c in ctrl.categories) c.id: c.name};

    iptvSyncRow(
      rowId: 'browser-streams',
      sortOrder: 3,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
      onFocusUp: () => iptvFocusRowItem(
        'browser-categories',
        selectedCatIdx >= 0 ? selectedCatIdx : 0,
      ),
    );

    final rows = ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final stream = list[i];
        return _StreamRowTile(
          stream: stream,
          ctrl: ctrl,
          categoryName: categoryNames[stream.categoryId] ?? '',
          listIndex: i,
          onLeftEdge: () => iptvFocusRowItem(
            'browser-categories',
            selectedCatIdx >= 0 ? selectedCatIdx : 0,
          ),
          onTap: () => _onStreamTap(stream),
        );
      },
    );
    if (!_LiveHealthProbe.usesScrollDebounce(context)) return rows;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: rows,
    );
  }

  Widget _buildStreamsEmpty() {
    final ctrl = widget.ctrl;
    if (ctrl.browserAllStreams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctrl.error ?? 'Failed to load channels — check connection',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            IptvPrimaryButton(
              icon: Icons.refresh_rounded,
              label: 'Reload',
              onPressed: ctrl.activeSection == null
                  ? null
                  : () => ctrl.openSection(ctrl.activeSection!),
            ),
          ],
        ),
      );
    }
    if (ctrl.activeSection == IptvSection.live && ctrl.liveOnly) {
      final msg = ctrl.isVerifyingAlive
          ? 'Checking streams…'
          : 'No alive streams found';
      return Center(
        child: Text(msg, style: GoogleFonts.poppins(color: Colors.white60)),
      );
    }
    return Center(
      child: Text(
        'No streams in this view',
        style: GoogleFonts.poppins(color: Colors.white60),
      ),
    );
  }

  void _onStreamTap(IptvStream s) {
    final ctrl = widget.ctrl;
    final p = ctrl.activePortal;
    if (p == null) return;
    if (s.kind == 'series') {
      ctrl.openSeries(s);
      return;
    }
    final url = IptvClient.streamUrl(p.portal, s);
    final channelGuide = s.kind == 'live'
        ? IptvChannelGuide.fromXtreamLive(
            portal: p,
            categories: ctrl.categories,
            streams: ctrl.browserAllStreams,
            initialStream: s,
            streamHealth: Map<String, bool>.from(ctrl.streamHealth),
          )
        : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen.singleStream(
          url: url,
          stream: s,
          portalName: p.name,
          channelGuide: channelGuide,
        ),
      ),
    );
  }
}

class _StreamThumbPlayHint extends StatelessWidget {
  const _StreamThumbPlayHint({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: active ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.34),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: active ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: ForjaShellColors.brandGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF111827),
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StreamCard extends StatefulWidget {
  final IptvStream stream;
  final IptvController ctrl;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  const _StreamCard({
    required this.stream,
    required this.ctrl,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onLeftEdge,
    this.onUpEdge,
  });

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: _hovered,
        focused: _focused,
      );

  void _onHover(bool hovered) {
    setState(() => _hovered = hovered);
    _syncLiveProbe(hovered || _focused);
  }

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    _syncLiveProbe(focused || _hovered);
  }

  void _syncLiveProbe(bool active) {
    if (widget.stream.kind != 'live') return;
    if (active) {
      widget.ctrl.scheduleLazyCheck(widget.stream);
    } else {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
  }

  Color _surfaceColor(bool active, bool? health) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _borderColor(bool active, bool? health) {
    if (widget.stream.kind != 'live' || health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    if (health) {
      return const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45);
    }
    return const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  void _showEpgSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EpgSheet(stream: widget.stream, ctrl: widget.ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (_, _) {
        final health = widget.stream.kind == 'live'
            ? widget.ctrl.healthFor(widget.stream.streamId)
            : null;
        final active = _active(context);
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: widget.stream.icon.isEmpty
                        ? const _StreamPlaceholder()
                        : Image.network(
                            widget.stream.icon,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _StreamPlaceholder(),
                            loadingBuilder: (_, child, p) =>
                                p == null ? child : const _StreamPlaceholder(),
                          ),
                  ),
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: active ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ShellCardPlayOverlay(active: true, visible: active),
                  if (health != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: health
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                          border: Border.all(color: Colors.black54, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Tooltip(
                message: widget.stream.name,
                waitDuration: const Duration(milliseconds: 600),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      widget.stream.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: GoogleFonts.poppins(
                        color: health == false ? Colors.white54 : Colors.white,
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.stream.kind == 'live')
              _EpgNowFooter(stream: widget.stream, ctrl: widget.ctrl),
          ],
        );
        Widget card = AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _surfaceColor(active, health),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor(active, health)),
          ),
          child: iptvTap(
            context: context,
            onTap: widget.onTap,
            borderRadius: 12,
            scaleOnFocus: 1.0,
            gridIndex: widget.gridIndex,
            gridColumns: widget.gridColumns,
            tvRowId: 'browser-streams',
            tvZone: ShellTvZone.grid,
            onLeftEdge: widget.onLeftEdge,
            onUpEdge: widget.onUpEdge,
            onFocusChange: _onFocus,
            onHoverChange: _onHover,
            child: column,
          ),
        );

        if (!iptvUseTvFocus(context) &&
            widget.stream.kind == 'live' &&
            widget.ctrl.epgEnabled) {
          card = GestureDetector(
            onLongPress: () => _showEpgSheet(context),
            child: card,
          );
        }

        if (widget.stream.kind != 'live') return card;

        return _LiveHealthProbe(
          stream: widget.stream,
          ctrl: widget.ctrl,
          child: card,
        );
      },
    );
  }
}

class _StreamRowTile extends StatefulWidget {
  const _StreamRowTile({
    required this.stream,
    required this.ctrl,
    required this.categoryName,
    required this.onTap,
    this.listIndex,
    this.onLeftEdge,
  });

  final IptvStream stream;
  final IptvController ctrl;
  final String categoryName;
  final VoidCallback onTap;
  final int? listIndex;
  final VoidCallback? onLeftEdge;

  @override
  State<_StreamRowTile> createState() => _StreamRowTileState();
}

class _StreamRowTileState extends State<_StreamRowTile> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: _hovered,
        focused: _focused,
      );

  void _onHover(bool hovered) {
    setState(() => _hovered = hovered);
    _syncLiveProbe(hovered || _focused);
  }

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    _syncLiveProbe(focused || _hovered);
  }

  void _syncLiveProbe(bool active) {
    if (widget.stream.kind != 'live') return;
    if (active) {
      widget.ctrl.scheduleLazyCheck(widget.stream);
    } else {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
  }

  Color _surfaceColor(bool active, bool? health) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _borderColor(bool active, bool? health) {
    if (widget.stream.kind != 'live' || health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    return health
        ? const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45)
        : const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (_, _) {
        final health = widget.stream.kind == 'live'
            ? widget.ctrl.healthFor(widget.stream.streamId)
            : null;
        final active = _active(context);
        final tile = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _surfaceColor(active, health),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor(active, health)),
            ),
            child: iptvTap(
              context: context,
              onTap: widget.onTap,
              borderRadius: 12,
              scaleOnFocus: 1.0,
              listIndex: widget.listIndex,
              tvItemIndex: widget.listIndex,
              tvRowId: 'browser-streams',
              tvZone: ShellTvZone.row,
              onLeftEdge: widget.onLeftEdge,
              onFocusChange: _onFocus,
              onHoverChange: _onHover,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.stream.icon.isEmpty
                                ? const _StreamPlaceholder()
                                : Image.network(
                                    widget.stream.icon,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const _StreamPlaceholder(),
                                    loadingBuilder: (_, child, p) => p == null
                                        ? child
                                        : const _StreamPlaceholder(),
                                  ),
                            _StreamThumbPlayHint(active: active),
                          ],
                        ),
                      ),
                    ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.stream.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: health == false
                                      ? Colors.white54
                                      : Colors.white,
                                  fontSize: 12,
                                  height: 1.18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.categoryName.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  widget.categoryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 10,
                                    height: 1.1,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (widget.stream.kind == 'live')
                                _EpgNowFooter(
                                  stream: widget.stream,
                                  ctrl: widget.ctrl,
                                ),
                            ],
                          ),
                        ),
                        if (health != null)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: health
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                            ),
                          )
                        else
                          AnimatedOpacity(
                            opacity: active ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.play_circle_outline_rounded,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (widget.stream.kind != 'live') return tile;
        return _LiveHealthProbe(
          stream: widget.stream,
          ctrl: widget.ctrl,
          child: tile,
        );
      },
    );
  }
}

/// Platform-specific lazy health probe — desktop hover, TV focus, mobile visibility.
class _LiveHealthProbe extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  final Widget child;

  const _LiveHealthProbe({
    required this.stream,
    required this.ctrl,
    required this.child,
  });

  static bool isDesktopPlatform() =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Mobile touch scrolling needs visibility + scroll debounce.
  static bool usesScrollDebounce(BuildContext context) =>
      !isDesktopPlatform() &&
      resolveShellProfile(context) == ShellProfile.mobile;

  @override
  Widget build(BuildContext context) {
    if (isDesktopPlatform() || isTvProfile(context)) {
      return child;
    }

    return VisibilityDetector(
      key: Key('live-${stream.streamId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.4) {
          ctrl.scheduleLazyCheck(stream);
        } else if (info.visibleFraction <= 0.05) {
          ctrl.cancelLazyCheck(stream.streamId);
        }
      },
      child: child,
    );
  }
}

/// Tiny "NOW · Title  •  HH:mm–HH:mm" strip rendered at the bottom of a live
/// `_StreamCard`. Quietly renders nothing while loading or when the panel has
/// no EPG for this channel — we never want a visible spinner per tile.
class _EpgNowFooter extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  const _EpgNowFooter({required this.stream, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
      future: ctrl.epgFor(stream),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null || data.isEmpty) return const SizedBox.shrink();
        final now = data.firstWhere((e) => e.isNow, orElse: () => data.first);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: now.isNow
                      ? const Color(0xFFEF4444)
                      : IptvShellStyle.accent.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  now.isNow ? 'NOW' : 'NEXT',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  now.title.isEmpty ? '—' : now.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Long-press detail sheet — lists the next few programmes with start times.
class _EpgSheet extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  const _EpgSheet({required this.stream, required this.ctrl});

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stream.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: FutureBuilder<List<EpgEntry>>(
                    future: ctrl.epgFor(stream, limit: 8),
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: IptvShellStyle.accent,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      final data = snap.data ?? const <EpgEntry>[];
                      if (data.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No EPG available for this channel.',
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in data)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 86,
                                    child: Text(
                                      '${_fmtTime(e.start)}–${_fmtTime(e.stop)}',
                                      style: GoogleFonts.poppins(
                                        color: e.isNow
                                            ? const Color(0xFFEF4444)
                                            : Colors.white60,
                                        fontSize: 11,
                                        fontWeight: e.isNow
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.title.isEmpty ? '—' : e.title,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (e.description.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              e.description,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamPlaceholder extends StatelessWidget {
  const _StreamPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.03),
      child: const Center(
        child: Icon(Icons.tv_rounded, color: Colors.white24, size: 36),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EPISODE LIST
// ─────────────────────────────────────────────────────────────────────────────
class _EpisodeListView extends StatelessWidget {
  final IptvController ctrl;
  final bool compact;
  const _EpisodeListView({required this.ctrl, required this.compact});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _PtAppBar(
            title: ctrl.activeSeries?.name ?? 'Series',
            onBack: ctrl.back,
          ),
          Expanded(
            child: ctrl.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: IptvShellStyle.accent,
                    ),
                  )
                : ctrl.episodes.isEmpty
                ? Center(
                    child: Text(
                      'No episodes found',
                      style: GoogleFonts.poppins(color: Colors.white60),
                    ),
                  )
                : _buildList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final bySeason = <int, List<IptvEpisode>>{};
    for (final e in ctrl.episodes) {
      bySeason.putIfAbsent(e.season, () => []).add(e);
    }
    final seasons = bySeason.keys.toList()..sort();
    final total = ctrl.episodes.length;
    iptvSyncRow(
      rowId: 'episodes',
      sortOrder: 0,
      itemCount: total,
      orientation: ShellTvRowOrientation.vertical,
    );
    var flatIndex = 0;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: seasons.length,
      itemBuilder: (_, si) {
        final season = seasons[si];
        final eps = bySeason[season]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Season $season',
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 22),
                ),
              ),
              ...eps.map((e) {
                final tile = _EpisodeTile(
                  episode: e,
                  ctrl: ctrl,
                  listIndex: flatIndex,
                );
                flatIndex++;
                return tile;
              }),
            ],
          ),
        );
      },
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final IptvEpisode episode;
  final IptvController ctrl;
  final int? listIndex;
  const _EpisodeTile({
    required this.episode,
    required this.ctrl,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: iptvTap(
        context: context,
        onTap: () {
          final p = ctrl.activePortal;
          if (p == null) return;
          final url = IptvClient.episodeUrl(p.portal, episode);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IptvPtPlayerScreen(
                sources: [IptvPlaySource(url: url, label: p.name)],
                title: 'Ep ${episode.episode} · ${episode.title}',
                subtitle: 'Season ${episode.season}',
                logoUrl: episode.image,
              ),
            ),
          );
        },
        borderRadius: 10,
        listIndex: listIndex,
        tvRowId: 'episodes',
        tvItemIndex: listIndex,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 96,
                  height: 56,
                  child: episode.image.isEmpty
                      ? const _StreamPlaceholder()
                      : Image.network(
                          episode.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _StreamPlaceholder(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ep ${episode.episode}  ${episode.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (episode.plot.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        episode.plot,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_outline_rounded,
                color: IptvShellStyle.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHANNELS HUB
// ─────────────────────────────────────────────────────────────────────────────
class _ChannelsHubView extends StatefulWidget {
  final IptvController ctrl;
  final bool compact;
  const _ChannelsHubView({required this.ctrl, required this.compact});

  @override
  State<_ChannelsHubView> createState() => _ChannelsHubViewState();
}

class _ChannelsHubViewState extends State<_ChannelsHubView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HardcodedChannel> get _filtered {
    if (_query.trim().isEmpty) return HardcodedChannels.all;
    final q = _query.trim().toLowerCase();
    return HardcodedChannels.all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.short.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return SafeArea(
      child: Column(
        children: [
          _PtAppBar(
            title: 'Channels',
            subtitle: 'Curated brands · auto-find live streams',
            onBack: widget.ctrl.back,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TvBrowseTextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v),
              browsePlaceholder: 'Search channels…',
              browseHintStyle: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 14,
              ),
              caretHeight: 18,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search channels…',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white54),
                suffixIcon: _query.isEmpty
                    ? null
                    : iptvCloseButton(
                        context,
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFF1A1A22),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: IptvShellStyle.accent,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'No channels match “$_query”.',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (_, c) {
                      final cross = (c.maxWidth ~/ 160).clamp(2, 8);
                      iptvSyncRow(
                        rowId: 'channels-hub',
                        sortOrder: 0,
                        itemCount: results.length,
                      );
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final ch = results[i];
                          return _ChannelTile(
                            channel: ch,
                            gridIndex: i,
                            gridColumns: cross,
                            onTap: () => widget.ctrl.openHardcodedChannel(ch),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final HardcodedChannel channel;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  const _ChannelTile({
    required this.channel,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: IptvShellStyle.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IptvShellStyle.border),
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 14,
          gridIndex: gridIndex,
          gridColumns: gridColumns,
          tvRowId: 'channels-hub',
          tvZone: ShellTvZone.grid,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  channel.short,
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 4),
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHANNEL RESULTS
// ─────────────────────────────────────────────────────────────────────────────
class _ChannelResultsView extends StatefulWidget {
  final IptvController ctrl;
  final bool compact;
  const _ChannelResultsView({required this.ctrl, required this.compact});

  @override
  State<_ChannelResultsView> createState() => _ChannelResultsViewState();
}

class _ChannelResultsViewState extends State<_ChannelResultsView> {
  bool _editMode = false;

  /// Selection tracks streamUrl, not index, so it stays valid when the
  /// displayed list is filtered/sorted by the search box & EPG-first sort.
  final Set<String> _selected = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Sort order: favorites first, then hits whose Xtream stream has an
  /// `epg_channel_id` (a hint that the panel ships EPG for it), then
  /// everything else. Stable within each tier so user-curated ordering is
  /// preserved. Then filter by the search query if set.
  List<ChannelHit> _displayList(IptvController ctrl) {
    final channelId = ctrl.activeHardcoded?.id ?? '';
    final fav = <ChannelHit>[];
    final epg = <ChannelHit>[];
    final rest = <ChannelHit>[];
    for (final h in ctrl.channelResults) {
      if (ctrl.isFavoriteHit(channelId, h)) {
        fav.add(h);
      } else if (h.stream.epgChannelId.isNotEmpty) {
        epg.add(h);
      } else {
        rest.add(h);
      }
    }
    var list = <ChannelHit>[...fav, ...epg, ...rest];
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((h) {
        return h.stream.name.toLowerCase().contains(q) ||
            h.portal.name.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final ch = ctrl.activeHardcoded;
    final displayed = _displayList(ctrl);
    return SafeArea(
      child: Column(
        children: [
          _PtAppBar(
            title: ch?.name ?? 'Channel',
            subtitle: ctrl.channelStatus.isEmpty
                ? '${displayed.length}${_query.isEmpty ? '' : '/${ctrl.channelResults.length}'} hits'
                : ctrl.channelStatus,
            onBack: ctrl.back,
            actions: [
              if (ctrl.channelResults.isNotEmpty)
                IptvIconAction(
                  tooltip: _editMode ? 'Done' : 'Edit',
                  onPressed: () => setState(() {
                    _editMode = !_editMode;
                    if (!_editMode) _selected.clear();
                  }),
                  icon: _editMode ? Icons.check_rounded : Icons.edit_rounded,
                  color: _editMode ? IptvShellStyle.accent : Colors.white70,
                ),
            ],
          ),
          if (ctrl.channelResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TvBrowseTextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _query = v),
                browsePlaceholder: 'Search hits…',
                browseHintStyle: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 14,
                ),
                caretHeight: 18,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search hits…',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white54),
                  suffixIcon: _query.isEmpty
                      ? null
                      : iptvCloseButton(
                          context,
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A22),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: IptvShellStyle.accent,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          if (_editMode && ctrl.channelResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: IptvShellStyle.chipSelectedBg.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Text(
                    _selected.isEmpty
                        ? 'Select streams'
                        : '${_selected.length} selected',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                  const Spacer(),
                  IptvTextAction(
                    icon:
                        displayed.isNotEmpty &&
                            _selected.containsAll(
                              displayed.map((h) => h.streamUrl),
                            )
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    label:
                        displayed.isNotEmpty &&
                            _selected.containsAll(
                              displayed.map((h) => h.streamUrl),
                            )
                        ? 'Clear'
                        : 'Select all',
                    onPressed: () {
                      setState(() {
                        final urls = displayed.map((h) => h.streamUrl).toSet();
                        final allSelected =
                            urls.isNotEmpty && _selected.containsAll(urls);
                        if (allSelected) {
                          _selected.removeAll(urls);
                        } else {
                          _selected.addAll(urls);
                        }
                      });
                    },
                  ),
                  if (_selected.isNotEmpty)
                    IptvIconAction(
                      tooltip: 'Delete selected',
                      onPressed: () async {
                        final indices = <int>{};
                        for (var i = 0; i < ctrl.channelResults.length; i++) {
                          if (_selected.contains(
                            ctrl.channelResults[i].streamUrl,
                          )) {
                            indices.add(i);
                          }
                        }
                        await ctrl.deleteChannelHits(indices);
                        setState(() {
                          _selected.clear();
                          _editMode = false;
                        });
                      },
                      icon: Icons.delete_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                ],
              ),
            ),
          if (ctrl.channelIsRunning) _buildSearchingBar(),
          Expanded(
            child: ctrl.channelResults.isEmpty
                ? _buildEmpty()
                : displayed.isEmpty
                ? Center(
                    child: Text(
                      'No hits match “$_query”.',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  )
                : _buildResults(displayed),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSearchingBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: IptvShellStyle.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.ctrl.channelStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          ),
          IptvTextAction(
            icon: Icons.stop_circle_rounded,
            label: 'Stop',
            onPressed: widget.ctrl.stopChannelSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final ctrl = widget.ctrl;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: IptvShellStyle.accent,
            ),
            const SizedBox(height: 16),
            Text(
              ctrl.channelIsRunning ? 'Searching…' : 'No hits yet',
              style: IptvShellStyle.pageTitle.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              ctrl.channelStatus.isEmpty
                  ? 'Tap "Search Again" or "Get More" to scan saved + new portals.'
                  : ctrl.channelStatus,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<ChannelHit> displayed) {
    final ctrl = widget.ctrl;
    return LayoutBuilder(
      builder: (_, c) {
        final cross = (c.maxWidth ~/ 320).clamp(1, 4);
        iptvSyncRow(
          rowId: 'channel-results',
          sortOrder: 0,
          itemCount: displayed.length,
        );
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 132,
          ),
          itemCount: displayed.length,
          itemBuilder: (_, i) {
            final hit = displayed[i];
            final selected = _selected.contains(hit.streamUrl);
            return _ChannelHitCard(
              hit: hit,
              ctrl: ctrl,
              editMode: _editMode,
              selected: selected,
              gridIndex: i,
              gridColumns: cross,
              isFavorite: ctrl.isFavoriteHit(
                ctrl.activeHardcoded?.id ?? '',
                hit,
              ),
              onToggleFavorite: () => ctrl.toggleFavoriteHit(hit),
              onTap: () {
                if (_editMode) {
                  setState(() {
                    if (selected) {
                      _selected.remove(hit.streamUrl);
                    } else {
                      _selected.add(hit.streamUrl);
                    }
                  });
                } else {
                  // Put the tapped hit first so the player actually opens it,
                  // and keep the rest as failover sources for the watchdog.
                  // Use the full original results list (not filtered) so the
                  // watchdog has every fallback available.
                  final ordered = [
                    hit,
                    ...ctrl.channelResults.where((h) => h != hit),
                  ];
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => IptvPtPlayerScreen.fromHits(
                        hits: ordered,
                        title: ctrl.activeHardcoded?.name ?? hit.stream.name,
                        logoUrl: hit.stream.icon,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () {
                if (!_editMode) {
                  setState(() {
                    _editMode = true;
                    _selected.add(hit.streamUrl);
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final ctrl = widget.ctrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IptvPrimaryButton(
              icon: Icons.refresh_rounded,
              label: 'Search Again',
              busy: ctrl.channelIsRunning,
              onPressed: ctrl.searchAgainChannel,
            ),
            const SizedBox(width: 8),
            IptvPrimaryButton(
              icon: Icons.add_circle_outline,
              label: 'Get More',
              subtle: true,
              onPressed: ctrl.channelIsRunning ? null : ctrl.getMoreChannels,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelHitCard extends StatelessWidget {
  final ChannelHit hit;
  final IptvController ctrl;
  final bool editMode;
  final bool selected;
  final bool isFavorite;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;
  const _ChannelHitCard({
    required this.hit,
    required this.ctrl,
    required this.editMode,
    required this.selected,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
    this.gridIndex,
    this.gridColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? IptvShellStyle.accent
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 12,
          gridIndex: gridIndex,
          gridColumns: gridColumns,
          tvRowId: 'channel-results',
          tvZone: ShellTvZone.grid,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                if (editMode) ...[
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: selected ? IptvShellStyle.accent : Colors.white30,
                  ),
                  const SizedBox(width: 8),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: hit.stream.icon.isEmpty
                        ? const _StreamPlaceholder()
                        : Image.network(
                            hit.stream.icon,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _StreamPlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: hit.stream.name,
                        waitDuration: const Duration(milliseconds: 600),
                        child: Text(
                          hit.stream.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'via ${_portalLabel(hit.portal)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                      _HitEpgNowRow(hit: hit, ctrl: ctrl),
                    ],
                  ),
                ),
                if (!editMode)
                  IptvIconAction(
                    tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
                    onPressed: onToggleFavorite,
                    icon: isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: isFavorite
                        ? const Color(0xFFFACC15)
                        : Colors.white38,
                    iconSize: 20,
                  ),
                if (!editMode)
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: IptvShellStyle.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _portalLabel(VerifiedPortal v) {
    final n = v.name.trim();
    if (n.isEmpty) return _redactUrl(v.portal.url);
    if (n.startsWith('http://') || n.startsWith('https://')) {
      return _redactUrl(n);
    }
    return n;
  }
}

/// Compact `[NOW] Programme` row rendered under the "via …" line on a hit
/// card. Stays empty (zero-height) when the portal has no EPG for this stream
/// so card layout doesn't shift visibly while loading.
class _HitEpgNowRow extends StatelessWidget {
  final ChannelHit hit;
  final IptvController ctrl;
  const _HitEpgNowRow({required this.hit, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
      future: ctrl.epgForHit(hit),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null || data.isEmpty) return const SizedBox.shrink();
        final now = data.firstWhere((e) => e.isNow, orElse: () => data.first);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: now.isNow
                      ? const Color(0xFFEF4444)
                      : IptvShellStyle.accent.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  now.isNow ? 'NOW' : 'NEXT',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  now.title.isEmpty ? '—' : now.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
