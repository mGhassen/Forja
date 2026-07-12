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

/// Top bar for catalog-first IPTV: section chips + portal control.
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

  String get _sectionTitle {
    return switch (ctrl.activeSection) {
      IptvSection.live => 'Live TV',
      IptvSection.vod => 'Movies',
      IptvSection.series => 'Series',
      null => 'IPTV',
    };
  }

  String get _portalLabel {
    final p = ctrl.activePortal;
    if (p == null) return 'Choose portal';
    final n = p.name.trim();
    if (n.isNotEmpty) return n;
    return p.portal.url;
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final hasPortal = ctrl.activePortal != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        ShellTokens.bodyHorizontalPadding,
        10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 24),
                ),
                if (hasPortal)
                  Text(
                    _portalLabel,
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
          _buildSectionChips(context, tvFocus),
          const SizedBox(width: 8),
          _buildPortalButton(context, tvFocus),
          const SizedBox(width: 4),
          IptvIconAction(
            tooltip: 'M3U Playlists',
            onPressed: onM3u,
            icon: Icons.playlist_play_rounded,
          ),
          IptvIconAction(
            tooltip: ctrl.browserSearchOpen ? 'Close search' : 'Search catalog',
            onPressed: onSearch,
            icon: ctrl.browserSearchOpen
                ? Icons.close_rounded
                : Icons.search_rounded,
            color: ctrl.browserSearchOpen ? IptvShellStyle.accent : null,
          ),
          if (hasPortal && ctrl.activeSection == IptvSection.live) ...[
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
    );
  }

  Widget _buildSectionChips(BuildContext context, bool tvFocus) {
    const sections = <(IptvSection, String, IconData)>[
      (IptvSection.live, 'Live', Icons.live_tv_rounded),
      (IptvSection.vod, 'Movies', Icons.movie_rounded),
      (IptvSection.series, 'Series', Icons.video_library_rounded),
    ];
    iptvSyncRow(
      rowId: 'iptv-sections',
      sortOrder: 0,
      itemCount: sections.length,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            ForjaShellChip(
              label: sections[i].$2,
              icon: sections[i].$3,
              selected: ctrl.activeSection == sections[i].$1,
              onTap: () => onSection(sections[i].$1),
              tvTabId: 'iptv',
              tvRowId: 'iptv-sections',
              listIndex: i,
              onDownEdge: tvFocus
                  ? () => iptvFocusRowItem('browser-categories')
                  : null,
            ),
            if (i < sections.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildPortalButton(BuildContext context, bool tvFocus) {
    final selected = ctrl.portalPanelOpen;
    final hasPortal = ctrl.activePortal != null;
    final label = hasPortal ? _portalLabel : 'Portals';
    return iptvTap(
      context: context,
      onTap: onTogglePanel,
      borderRadius: 20,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-sections',
      tvItemIndex: 3,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: shellChipDecoration(
          selected: selected || !hasPortal,
          radius: 20,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPortal ? Icons.dns_rounded : Icons.add_link_rounded,
              size: 16,
              color: hasPortal ? Colors.white : IptvShellStyle.accent,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              selected ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: Colors.white70,
            ),
          ],
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
            Text(
              'No portals yet',
              style: IptvShellStyle.headerTitle,
            ),
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
      sortOrder: 1,
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
          onLeftEdge: widget.ctrl.portalPanelOpen
              ? null
              : () => iptvFocusRowItem('browser-categories'),
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
