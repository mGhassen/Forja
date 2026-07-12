import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';

const _kShelfPillHeight = 40.0;

/// Colored Live / Movies / Series shelf — same hues as the old section tiles.
class _IptvSectionShelfSpec {
  const _IptvSectionShelfSpec({
    required this.section,
    required this.label,
    required this.icon,
    required this.colors,
  });

  final IptvSection section;
  final String label;
  final IconData icon;
  final List<Color> colors;
}

const _kSectionShelf = <_IptvSectionShelfSpec>[
  _IptvSectionShelfSpec(
    section: IptvSection.live,
    label: 'Live',
    icon: Icons.live_tv_rounded,
    colors: [Color(0xFFEF4444), Color(0xFF7C2D12)],
  ),
  _IptvSectionShelfSpec(
    section: IptvSection.vod,
    label: 'Movies',
    icon: Icons.movie_rounded,
    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  ),
  _IptvSectionShelfSpec(
    section: IptvSection.series,
    label: 'Series',
    icon: Icons.video_library_rounded,
    colors: [Color(0xFF374151), Color(0xFF1CE783)],
  ),
];

/// Top bar for catalog-first IPTV: colored shelf left, tools right.
class IptvCatalogTopBar extends StatelessWidget {
  const IptvCatalogTopBar({
    super.key,
    required this.ctrl,
    required this.onTogglePanel,
    required this.onSection,
    required this.onSearch,
    required this.onM3u,
  });

  final IptvController ctrl;
  final VoidCallback onTogglePanel;
  final ValueChanged<IptvSection> onSection;
  final VoidCallback onSearch;
  final VoidCallback onM3u;

  String get _portalLabel {
    final p = ctrl.activePortal;
    if (p == null) return 'Choose portal';
    final n = p.name.trim();
    if (n.isNotEmpty) return n;
    return p.portal.url;
  }

  void _focusDownFromTopBar() {
    if (!iptvFocusRowItem('browser-categories')) {
      iptvFocusRowItem('browser-streams');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPortal = ctrl.activePortal != null;
    final toolCount = 2 +
        (hasPortal && ctrl.activeSection == IptvSection.live ? 2 : 0);

    iptvSyncRow(
      rowId: 'iptv-sections',
      sortOrder: 0,
      itemCount: _kSectionShelf.length,
      onFocusUp: null,
    );
    iptvSyncRow(
      rowId: 'iptv-top-tools',
      sortOrder: 1,
      itemCount: toolCount + 1, // + portal button
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShellTokens.bodyHorizontalPadding,
        12,
        12,
        10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSectionShelf(context),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildPortalPill(context),
            ),
          ),
          _buildTopTools(context, hasPortal),
        ],
      ),
    );
  }

  Widget _buildSectionShelf(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _kSectionShelf.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _IptvSectionShelfPill(
            spec: _kSectionShelf[i],
            selected: ctrl.activeSection == _kSectionShelf[i].section,
            listIndex: i,
            onTap: () => onSection(_kSectionShelf[i].section),
            onDownEdge: _focusDownFromTopBar,
            onRightEdge: i == _kSectionShelf.length - 1
                ? () => iptvFocusRowItem('iptv-top-tools', 0)
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildPortalPill(BuildContext context) {
    final selected = ctrl.portalPanelOpen;
    final hasPortal = ctrl.activePortal != null;
    return iptvTap(
      context: context,
      onTap: onTogglePanel,
      borderRadius: _kShelfPillHeight / 2,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-top-tools',
      tvItemIndex: 0,
      onDownEdge: _focusDownFromTopBar,
      onLeftEdge: () =>
          iptvFocusRowItem('iptv-sections', _kSectionShelf.length - 1),
      onRightEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: _kShelfPillHeight,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(_kShelfPillHeight / 2),
          border: Border.all(
            color: !hasPortal
                ? IptvShellStyle.accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: selected ? 0.35 : 0.24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPortal ? Icons.dns_rounded : Icons.add_link_rounded,
              size: 18,
              color: hasPortal ? Colors.white : IptvShellStyle.accent,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hasPortal ? _portalLabel : 'Portals',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              selected ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTools(BuildContext context, bool hasPortal) {
    var toolIndex = 1;
    final tools = <Widget>[
      _IptvTopTool(
        tooltip: 'M3U Playlists',
        icon: Icons.playlist_play_rounded,
        onTap: onM3u,
        tvItemIndex: toolIndex++,
        onDownEdge: _focusDownFromTopBar,
      ),
      _IptvTopTool(
        tooltip: ctrl.browserSearchOpen ? 'Close search' : 'Search catalog',
        icon: ctrl.browserSearchOpen
            ? Icons.close_rounded
            : Icons.search_rounded,
        active: ctrl.browserSearchOpen,
        onTap: onSearch,
        tvItemIndex: toolIndex++,
        onDownEdge: _focusDownFromTopBar,
      ),
    ];
    if (hasPortal && ctrl.activeSection == IptvSection.live) {
      tools.add(
        _IptvTopTool(
          tooltip: 'Reload channels',
          icon: Icons.refresh_rounded,
          onTap: ctrl.isLoading
              ? null
              : () => ctrl.openSection(IptvSection.live),
          tvItemIndex: toolIndex++,
          onDownEdge: _focusDownFromTopBar,
        ),
      );
      tools.add(
        _IptvTopTool(
          tooltip: ctrl.isVerifyingAlive
              ? 'Stop alive check'
              : 'Re-check all streams',
          icon: ctrl.isVerifyingAlive
              ? Icons.stop_circle_rounded
              : Icons.verified_outlined,
          active: ctrl.isVerifyingAlive,
          onTap: ctrl.isVerifyingAlive
              ? ctrl.stopAliveCheck
              : ctrl.recheckAlive,
          tvItemIndex: toolIndex,
          onDownEdge: _focusDownFromTopBar,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in tools) ...[
          const SizedBox(width: 4),
          t,
        ],
      ],
    );
  }
}

class _IptvSectionShelfPill extends StatelessWidget {
  const _IptvSectionShelfPill({
    required this.spec,
    required this.selected,
    required this.listIndex,
    required this.onTap,
    this.onDownEdge,
    this.onRightEdge,
  });

  final _IptvSectionShelfSpec spec;
  final bool selected;
  final int listIndex;
  final VoidCallback onTap;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightEdge;

  @override
  Widget build(BuildContext context) {
    return iptvTap(
      context: context,
      onTap: onTap,
      borderRadius: _kShelfPillHeight / 2,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-sections',
      listIndex: listIndex,
      tvItemIndex: listIndex,
      onDownEdge: onDownEdge,
      onRightEdge: onRightEdge,
      onLeftEdge: listIndex == 0
          ? null
          : () => iptvFocusRowItem('iptv-sections', listIndex - 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: _kShelfPillHeight,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? spec.colors
                : [
                    spec.colors[0].withValues(alpha: 0.28),
                    spec.colors[1].withValues(alpha: 0.18),
                  ],
          ),
          borderRadius: BorderRadius.circular(_kShelfPillHeight / 2),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: spec.colors[0].withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Text(
              spec.label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IptvTopTool extends StatelessWidget {
  const _IptvTopTool({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.tvItemIndex,
    this.active = false,
    this.onDownEdge,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final int tvItemIndex;
  final bool active;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: iptvTap(
        context: context,
        onTap: onTap,
        borderRadius: 20,
        tvZone: ShellTvZone.topBar,
        tvRowId: 'iptv-top-tools',
        tvItemIndex: tvItemIndex,
        onDownEdge: onDownEdge,
        onLeftEdge: () => iptvFocusRowItem('iptv-top-tools', tvItemIndex - 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? IptvShellStyle.accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? IptvShellStyle.accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? IptvShellStyle.accent : Colors.white,
          ),
        ),
      ),
    );
  }
}

class IptvPortalPanel extends StatefulWidget {
  const IptvPortalPanel({
    super.key,
    required this.ctrl,
    required this.width,
    required this.onClose,
  });

  final IptvController ctrl;
  final double width;
  final VoidCallback onClose;

  @override
  State<IptvPortalPanel> createState() => _IptvPortalPanelState();
}

class _IptvPortalPanelState extends State<IptvPortalPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _panelFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  List<VerifiedPortal> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.ctrl.verified;
    return widget.ctrl.verified.where((v) {
      return v.name.toLowerCase().contains(q) ||
          v.portal.url.toLowerCase().contains(q) ||
          v.portal.username.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final list = _filtered;
    final activeKey = ctrl.activePortal?.key;

    return Focus(
      focusNode: _panelFocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: IptvShellStyle.surface,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              if (ctrl.editMode && ctrl.verified.isNotEmpty) _buildEditBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TvBrowseTextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: (v) => setState(() => _query = v),
                  browsePlaceholder: 'Search portals…',
                  browseHintStyle: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  caretHeight: 18,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search portals…',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white54, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  ctrl.statusText.isEmpty
                      ? '${list.length} portal${list.length == 1 ? '' : 's'}'
                      : ctrl.statusText,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? _buildEmpty()
                    : _buildPortalList(list, activeKey),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ctrl = widget.ctrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Portals',
            style: IptvShellStyle.headerTitle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          IptvIconAction(
            tooltip: 'Add portal',
            onPressed: () => _showAddDialog(context),
            icon: Icons.add_rounded,
          ),
          if (ctrl.verified.isNotEmpty)
            IptvIconAction(
              tooltip: ctrl.editMode ? 'Done' : 'Edit',
              onPressed: ctrl.toggleEditMode,
              icon: ctrl.editMode ? Icons.check_rounded : Icons.edit_rounded,
              color: ctrl.editMode ? IptvShellStyle.accent : Colors.white70,
            ),
          iptvCloseButton(context, onTap: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildEditBar() {
    final ctrl = widget.ctrl;
    final allSelected = ctrl.selected.length == ctrl.verified.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          IptvIconAction(
            tooltip: 'Delete selected',
            onPressed: ctrl.selected.isEmpty ? null : ctrl.deleteSelected,
            icon: Icons.delete_rounded,
            color: ctrl.selected.isEmpty
                ? Colors.white24
                : const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt_rounded,
                size: 48, color: IptvShellStyle.accent),
            const SizedBox(height: 12),
            Text('No portals yet', style: IptvShellStyle.headerTitle),
            const SizedBox(height: 8),
            Text(
              'Scrape or add a portal to browse channels.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalList(List<VerifiedPortal> list, String? activeKey) {
    iptvSyncRow(
      rowId: 'portals',
      sortOrder: 2,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final v = list[i];
        final isActive = v.key == activeKey;
        final isSelected = widget.ctrl.selected.contains(v.key);
        final isFav = widget.ctrl.isFavoritePortal(v.key);
        return iptvTap(
          context: context,
          onTap: () {
            if (widget.ctrl.editMode) {
              widget.ctrl.toggleSelect(v.key);
            } else {
              widget.ctrl.selectPortal(v);
            }
          },
          borderRadius: 10,
          listIndex: i,
          tvRowId: 'portals',
          tvItemIndex: i,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? IptvShellStyle.accent.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive || isSelected
                    ? IptvShellStyle.accent
                    : Colors.white.withValues(alpha: 0.06),
                width: isActive || isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (widget.ctrl.editMode)
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? IptvShellStyle.accent
                        : Colors.white30,
                    size: 20,
                  )
                else if (isFav)
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFBBF24), size: 18)
                else
                  Icon(Icons.tv_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name.trim().isEmpty ? v.portal.url : v.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        v.portal.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.ctrl.editMode)
                  iptvTap(
                    context: context,
                    onTap: () => widget.ctrl.toggleFavoritePortal(v.key),
                    borderRadius: 16,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 18,
                        color: isFav
                            ? const Color(0xFFFBBF24)
                            : Colors.white38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final ctrl = widget.ctrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSourcePicker(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: IptvPrimaryButton(
                  icon: ctrl.isScraping
                      ? Icons.stop_circle_rounded
                      : Icons.travel_explore,
                  label: ctrl.isScraping ? 'Stop' : 'Scrape',
                  onPressed:
                      ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
                ),
              ),
              if (ctrl.canGetMore) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: IptvPrimaryButton(
                    icon: Icons.add_circle_outline,
                    label: 'Get more',
                    subtle: true,
                    onPressed: ctrl.isScraping ? null : ctrl.getMore,
                  ),
                ),
              ],
            ],
          ),
          if (ctrl.verified.isNotEmpty) ...[
            const SizedBox(height: 8),
            IptvPrimaryButton(
              icon: Icons.refresh_rounded,
              label: 'Re-verify saved',
              subtle: true,
              onPressed: ctrl.runVerification,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourcePicker() {
    final items = <(CatalogSource, String)>[
      (CatalogSource.best, 'Source 1'),
      (CatalogSource.works, 'Source 2'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: iptvTap(
              context: context,
              onTap: widget.ctrl.isScraping
                  ? null
                  : () => widget.ctrl.setScrapeSource(items[i].$1),
              borderRadius: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: shellChipDecoration(
                  selected: widget.ctrl.scrapeSource == items[i].$1,
                  radius: 10,
                ),
                alignment: Alignment.center,
                child: Text(
                  items[i].$2,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (i < items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final ctrl = widget.ctrl;
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
                  _portalInput(urlCtrl, 'http://portal.example.com:8080', 'URL'),
                  const SizedBox(height: 8),
                  _portalInput(userCtrl, 'username', 'Username'),
                  const SizedBox(height: 8),
                  _portalInput(passCtrl, 'password', 'Password', obscure: true),
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

  Widget _portalInput(
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
