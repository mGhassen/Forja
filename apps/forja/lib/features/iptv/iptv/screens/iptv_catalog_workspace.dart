import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';

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

const _kShelfTabHeight = 36.0;
const _kShelfTabRadius = 8.0;
const _kSearchCollapsed = 40.0;
const _kSearchExpanded = 260.0;

/// Top bar: solid shelf tabs left · expanding search + portal right.
class IptvCatalogTopBar extends StatefulWidget {
  const IptvCatalogTopBar({
    super.key,
    required this.ctrl,
    required this.onTogglePanel,
    required this.onSection,
  });

  final IptvController ctrl;
  final VoidCallback onTogglePanel;
  final ValueChanged<IptvSection> onSection;

  @override
  State<IptvCatalogTopBar> createState() => _IptvCatalogTopBarState();
}

class _IptvCatalogTopBarState extends State<IptvCatalogTopBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final AnimationController _searchAnim;
  late final Animation<double> _searchExpand;
  bool _searchDialogOpen = false;

  IptvController get ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ctrl.browserSearch;
    _searchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _searchExpand = CurvedAnimation(
      parent: _searchAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    if (ctrl.browserSearchOpen) {
      _searchAnim.value = 1;
    }
    ctrl.addListener(_onCtrl);
  }

  @override
  void dispose() {
    ctrl.removeListener(_onCtrl);
    _searchAnim.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (!mounted) return;
    final open = ctrl.browserSearchOpen;
    if (open && _searchAnim.status != AnimationStatus.completed) {
      _searchAnim.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    } else if (!open && _searchAnim.status != AnimationStatus.dismissed) {
      _searchAnim.reverse();
      _searchCtrl.clear();
      _searchFocus.unfocus();
    }
    setState(() {});
  }

  String get _portalLabel {
    final p = ctrl.activePortal;
    if (p == null) return 'Portals';
    final n = p.name.trim();
    if (n.isNotEmpty) return n;
    return p.portal.url;
  }

  void _focusDownFromTopBar() {
    if (!iptvFocusRowItem('browser-categories') &&
        !iptvFocusRowItem('browser-category-chips')) {
      iptvFocusRowItem('browser-streams');
    }
  }

  Future<void> _openSearch(
    BuildContext context, {
    required bool compact,
  }) async {
    if (!compact) {
      if (ctrl.browserSearchOpen) return;
      ctrl.openBrowserSearch();
      return;
    }

    if (_searchDialogOpen) {
      _searchFocus.requestFocus();
      return;
    }

    _searchCtrl.text = ctrl.browserSearch;
    ctrl.openBrowserSearch();
    _searchDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => ShellScope.rehost(
        context,
        _IptvCatalogSearchDialog(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: ctrl.setBrowserSearch,
          onClear: _clearSearchQuery,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
    _searchDialogOpen = false;
    if (mounted && ctrl.browserSearchOpen) {
      _closeSearch();
    }
  }

  void _closeSearch() {
    ctrl.closeBrowserSearch();
  }

  void _clearSearchQuery() {
    _searchCtrl.clear();
    ctrl.setBrowserSearch('');
  }

  @override
  Widget build(BuildContext context) {
    iptvSyncRow(
      rowId: 'iptv-sections',
      sortOrder: 0,
      itemCount: _kSectionShelf.length,
    );
    iptvSyncRow(
      rowId: 'iptv-section-reload',
      sortOrder: 0,
      itemCount: _kSectionShelf.length,
    );
    iptvSyncRow(rowId: 'iptv-top-tools', sortOrder: 1, itemCount: 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final leftPadding = ShellTokens.compactChromeLeadingInset(
          context,
        ).clamp(ShellTokens.bodyHorizontalPadding, constraints.maxWidth * 0.28);

        return Padding(
          padding: EdgeInsets.fromLTRB(leftPadding, 10, 12, 8),
          child: Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildShelf(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              compact
                  ? _buildSearchIcon(context, compact: true)
                  : _buildExpandingSearch(context),
              const SizedBox(width: 8),
              _buildPortalButton(context, compact: compact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShelf(BuildContext context) {
    return Container(
      height: _kShelfTabHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_kShelfTabRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _kSectionShelf.length; i++)
            _IptvSectionShelfTab(
              spec: _kSectionShelf[i],
              selected: ctrl.activeSection == _kSectionShelf[i].section,
              listIndex: i,
              isFirst: i == 0,
              isLast: i == _kSectionShelf.length - 1,
              onTap: () => widget.onSection(_kSectionShelf[i].section),
              onReload: () => ctrl.reloadSection(_kSectionShelf[i].section),
              onDownEdge: _focusDownFromTopBar,
              onRightEdge: i == _kSectionShelf.length - 1
                  ? () => iptvFocusRowItem('iptv-top-tools', 0)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildExpandingSearch(BuildContext context) {
    return AnimatedBuilder(
      animation: _searchExpand,
      builder: (context, _) {
        final t = _searchExpand.value;
        final width =
            _kSearchCollapsed + (_kSearchExpanded - _kSearchCollapsed) * t;

        // Field lays out at full width; ClipRect reveals it as the shell expands.
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            height: _kSearchCollapsed,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.centerRight,
                clipBehavior: Clip.hardEdge,
                children: [
                  Opacity(
                    opacity: t,
                    child: IgnorePointer(
                      ignoring: t < 0.55,
                      child: OverflowBox(
                        maxWidth: _kSearchExpanded,
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: _kSearchExpanded,
                          child: _buildSearchField(context),
                        ),
                      ),
                    ),
                  ),
                  if (t < 0.95)
                    Opacity(
                      opacity: (1.0 - t * 1.4).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: t > 0.2,
                        child: _buildSearchIcon(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchIcon(BuildContext context, {bool compact = false}) {
    return iptvTap(
      context: context,
      onTap: () => _openSearch(context, compact: compact),
      borderRadius: _kSearchCollapsed / 2,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-top-tools',
      tvItemIndex: 0,
      onDownEdge: _focusDownFromTopBar,
      onLeftEdge: () =>
          iptvFocusRowItem('iptv-sections', _kSectionShelf.length - 1),
      onRightEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
      child: Container(
        width: _kSearchCollapsed,
        height: _kSearchCollapsed,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: _kSearchCollapsed,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TvBrowseTextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: ctrl.setBrowserSearch,
              onEscape: _closeSearch,
              browsePlaceholder: 'Search…',
              browseHintStyle: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
              ),
              caretHeight: 16,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          iptvTap(
            context: context,
            onTap: _closeSearch,
            borderRadius: 16,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalButton(BuildContext context, {bool compact = false}) {
    final selected = ctrl.portalPanelOpen;
    final hasPortal = ctrl.activePortal != null;
    return iptvTap(
      context: context,
      onTap: widget.onTogglePanel,
      borderRadius: _kShelfTabRadius,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-top-tools',
      tvItemIndex: 1,
      onDownEdge: _focusDownFromTopBar,
      onLeftEdge: () => iptvFocusRowItem('iptv-top-tools', 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: _kShelfTabHeight,
        constraints: BoxConstraints(maxWidth: compact ? 44 : 180),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(_kShelfTabRadius),
          border: Border.all(
            color: !hasPortal
                ? IptvShellStyle.accent.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: selected ? 0.28 : 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPortal ? Icons.dns_rounded : Icons.add_link_rounded,
              size: 16,
              color: hasPortal ? Colors.white : IptvShellStyle.accent,
            ),
            if (!compact) ...[
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  _portalLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                selected
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: Colors.white60,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IptvCatalogSearchDialog extends StatefulWidget {
  const _IptvCatalogSearchDialog({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  State<_IptvCatalogSearchDialog> createState() =>
      _IptvCatalogSearchDialogState();
}

class _IptvCatalogSearchDialogState extends State<_IptvCatalogSearchDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: IptvShellStyle.dialogSurface(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Search IPTV',
                        style: IptvShellStyle.overlayTitle,
                      ),
                    ),
                    iptvCloseButton(context, onTap: widget.onClose),
                  ],
                ),
                const SizedBox(height: 14),
                TvBrowseTextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: widget.onChanged,
                  onEscape: widget.onClose,
                  browsePlaceholder: 'Search channels or categories…',
                  browseHintStyle: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  caretHeight: 18,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search channels or categories…',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    suffixIcon: widget.controller.text.isEmpty
                        ? null
                        : iptvCloseButton(context, onTap: widget.onClear),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: IptvShellStyle.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: IptvShellStyle.border),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Solid rectangle shelf tab — color only when selected / hovered / focused.
/// Hover/focus expands right to reveal a catalog reload control.
class _IptvSectionShelfTab extends StatefulWidget {
  const _IptvSectionShelfTab({
    required this.spec,
    required this.selected,
    required this.listIndex,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onReload,
    this.onDownEdge,
    this.onRightEdge,
  });

  final _IptvSectionShelfSpec spec;
  final bool selected;
  final int listIndex;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onReload;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_IptvSectionShelfTab> createState() => _IptvSectionShelfTabState();
}

class _IptvSectionShelfTabState extends State<_IptvSectionShelfTab> {
  bool _hover = false;
  bool _focused = false;

  bool get _revealReload => _hover || _focused;

  BorderRadius get _radius {
    final r = Radius.circular(_kShelfTabRadius - 1);
    if (widget.isFirst && widget.isLast) return BorderRadius.all(r);
    if (widget.isFirst) {
      return BorderRadius.only(topLeft: r, bottomLeft: r);
    }
    if (widget.isLast) {
      return BorderRadius.only(topRight: r, bottomRight: r);
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    final showColor = widget.selected || _hover || _focused;
    final accent = widget.spec.section == IptvSection.series
        ? widget.spec.colors.last
        : widget.spec.colors.first;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: _kShelfTabHeight,
        decoration: BoxDecoration(
          color: showColor
              ? (widget.selected ? accent : accent.withValues(alpha: 0.55))
              : Colors.transparent,
          borderRadius: _radius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iptvTap(
              context: context,
              onTap: widget.onTap,
              borderRadius: _kShelfTabRadius,
              scaleOnFocus: 1.0,
              tvZone: ShellTvZone.topBar,
              tvRowId: 'iptv-sections',
              listIndex: widget.listIndex,
              tvItemIndex: widget.listIndex,
              onDownEdge: widget.onDownEdge,
              onRightEdge: _revealReload
                  ? () => iptvFocusRowItem(
                      'iptv-section-reload',
                      widget.listIndex,
                    )
                  : widget.onRightEdge,
              onLeftEdge: widget.listIndex == 0
                  ? null
                  : () =>
                        iptvFocusRowItem('iptv-sections', widget.listIndex - 1),
              onFocusChange: (f) => setState(() => _focused = f),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.spec.icon,
                      size: 16,
                      color: showColor ? Colors.white : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.spec.label,
                      style: GoogleFonts.inter(
                        color: showColor ? Colors.white : Colors.white60,
                        fontSize: 12.5,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: _revealReload ? 1 : 0,
                child: iptvTap(
                  context: context,
                  onTap: widget.onReload,
                  borderRadius: 8,
                  scaleOnFocus: 1.0,
                  tvZone: ShellTvZone.topBar,
                  tvRowId: 'iptv-section-reload',
                  listIndex: widget.listIndex,
                  tvItemIndex: widget.listIndex,
                  onLeftEdge: () =>
                      iptvFocusRowItem('iptv-sections', widget.listIndex),
                  onRightEdge: widget.onRightEdge,
                  onDownEdge: widget.onDownEdge,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: 'Reload catalog',
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: showColor
                            ? Colors.white.withValues(alpha: 0.95)
                            : Colors.white60,
                      ),
                    ),
                  ),
                ),
              ),
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
  bool _searchOpen = false;

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

  void _openSearch() {
    if (_searchOpen) {
      _searchFocus.requestFocus();
      return;
    }
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    if (!_searchOpen && _query.isEmpty) return;
    _searchCtrl.clear();
    setState(() {
      _searchOpen = false;
      _query = '';
    });
    _searchFocus.unfocus();
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      _openSearch();
    }
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
          if (_searchOpen) {
            _closeSearch();
            return KeyEventResult.handled;
          }
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
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: _searchOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TvBrowseTextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      onChanged: (v) => setState(() => _query = v),
                      onEscape: _closeSearch,
                      browsePlaceholder: 'Search portals…',
                      browseHintStyle: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      caretHeight: 18,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search portals…',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : iptvCloseButton(
                                context,
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                  _searchFocus.requestFocus();
                                },
                              ),
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
            tooltip: _searchOpen ? 'Close search' : 'Search portals',
            onPressed: _toggleSearch,
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            color: _searchOpen ? IptvShellStyle.accent : null,
          ),
          IptvIconAction(
            tooltip: ctrl.isScraping ? 'Stop scrape' : 'Scrape portals',
            onPressed: ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
            icon: ctrl.isScraping
                ? Icons.stop_circle_rounded
                : Icons.travel_explore_rounded,
            color: ctrl.isScraping ? IptvShellStyle.accent : null,
          ),
          IptvIconAction(
            tooltip: 'Add portal',
            onPressed: () => _showAddDialog(context),
            icon: Icons.add_rounded,
          ),
          iptvCloseButton(context, onTap: widget.onClose),
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
            Icon(
              Icons.satellite_alt_rounded,
              size: 48,
              color: IptvShellStyle.accent,
            ),
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
    final ctrl = widget.ctrl;
    iptvSyncRow(
      rowId: 'portals',
      sortOrder: 2,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final v = list[i];
        return _PortalHoverTile(
          portal: v,
          ctrl: ctrl,
          isActive: v.key == activeKey,
          listIndex: i,
          onEdit: () => _showPortalDialog(context, existing: v),
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context) =>
      _showPortalDialog(context);

  Future<void> _showPortalDialog(
    BuildContext context, {
    VerifiedPortal? existing,
  }) {
    widget.ctrl.addError = null;
    return showDialog<void>(
      context: context,
      builder: (ctx) => ShellScope.rehost(
        context,
        _PortalFormDialog(ctrl: widget.ctrl, existing: existing),
      ),
    );
  }
}

class _PortalFormDialog extends StatefulWidget {
  const _PortalFormDialog({required this.ctrl, this.existing});

  final IptvController ctrl;
  final VerifiedPortal? existing;

  @override
  State<_PortalFormDialog> createState() => _PortalFormDialogState();
}

class _PortalFormDialogState extends State<_PortalFormDialog> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  bool _obscurePassword = true;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _urlCtrl = TextEditingController(text: e?.portal.url ?? '');
    _userCtrl = TextEditingController(text: e?.portal.username ?? '');
    _passCtrl = TextEditingController(text: e?.portal.password ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ctrl = widget.ctrl;
    if (_editing) {
      await ctrl.updatePortal(
        existing: widget.existing!,
        url: _urlCtrl.text,
        username: _userCtrl.text,
        password: _passCtrl.text,
      );
    } else {
      await ctrl.addManual(
        url: _urlCtrl.text,
        username: _userCtrl.text,
        password: _passCtrl.text,
      );
    }
    if (ctrl.addError == null && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _cancel() {
    widget.ctrl.dismissAddDialog();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DecoratedBox(
            decoration: IptvShellStyle.dialogSurface(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editing ? 'Edit Portal' : 'Add Portal',
                          style: IptvShellStyle.overlayTitle,
                        ),
                      ),
                      ForjaPlainIcon(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        color: IptvShellStyle.iconMuted,
                        size: 22,
                        onTap: ctrl.isAdding ? null : _cancel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _portalField(
                    _urlCtrl,
                    'URL',
                    hint: 'http://portal.example.com:8080',
                  ),
                  const SizedBox(height: 18),
                  _portalField(_userCtrl, 'Username', hint: 'username'),
                  const SizedBox(height: 18),
                  _portalField(
                    _passCtrl,
                    'Password',
                    hint: 'password',
                    obscure: _obscurePassword,
                    suffix: ForjaPlainIcon(
                      icon: _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      color: IptvShellStyle.iconMuted,
                      size: 20,
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  if (ctrl.addError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      ctrl.addError!,
                      style: GoogleFonts.poppins(
                        color: IptvShellStyle.liveBadge,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _portalDialogAction(
                        icon: Icons.close_rounded,
                        label: 'Cancel',
                        color: IptvShellStyle.textSecondary,
                        onTap: ctrl.isAdding ? null : _cancel,
                      ),
                      const SizedBox(width: 12),
                      _portalSaveAction(ctrl),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _portalDialogAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.02,
      pressScale: 0.98,
      builder: (hover, pressed) {
        final fg = (hover || pressed) ? ForjaShellColors.iconHover : color;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: fg,
                  fontSize: 14,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _portalSaveAction(IptvController ctrl) {
    final label = ctrl.isAdding
        ? (_editing ? 'Saving…' : 'Adding…')
        : (_editing ? 'Save' : 'Add');
    final icon = _editing ? Icons.check_rounded : Icons.add_rounded;

    if (ctrl.isAdding) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: IptvShellStyle.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: IptvShellStyle.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return _portalDialogAction(
      icon: icon,
      label: label,
      color: IptvShellStyle.textPrimary,
      fontWeight: FontWeight.w600,
      onTap: _submit,
    );
  }

  Widget _portalField(
    TextEditingController c,
    String label, {
    String? hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            color: IptvShellStyle.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          obscureText: obscure,
          style: GoogleFonts.poppins(
            color: IptvShellStyle.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 14,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: IptvShellStyle.border),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: IptvShellStyle.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: IptvShellStyle.textPrimary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PortalHoverTile extends StatefulWidget {
  const _PortalHoverTile({
    required this.portal,
    required this.ctrl,
    required this.isActive,
    required this.listIndex,
    required this.onEdit,
  });

  final VerifiedPortal portal;
  final IptvController ctrl;
  final bool isActive;
  final int listIndex;
  final VoidCallback onEdit;

  @override
  State<_PortalHoverTile> createState() => _PortalHoverTileState();
}

class _PortalHoverTileState extends State<_PortalHoverTile> {
  static const _actionW = 108.0;
  static const _revealDelay = Duration(seconds: 3);
  static const _rightHotFraction = 0.10;
  static const _statusSlot = 18.0;

  bool _lineHover = false;
  bool _focused = false;
  bool _actionsOpen = false;
  Timer? _revealTimer;

  bool get _reveal => _focused || _actionsOpen;

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _armRevealTimer() {
    _revealTimer?.cancel();
    _revealTimer = Timer(_revealDelay, () {
      if (!mounted || !_lineHover) return;
      setState(() => _actionsOpen = true);
    });
  }

  void _openActions() {
    _revealTimer?.cancel();
    if (!_actionsOpen) setState(() => _actionsOpen = true);
  }

  void _clearHover() {
    _revealTimer?.cancel();
    _revealTimer = null;
    setState(() {
      _lineHover = false;
      _actionsOpen = false;
    });
  }

  void _copy() {
    final p = widget.portal.portal;
    final cleanUrl = p.url
        .replaceFirst('http://', '')
        .replaceFirst('https://', '');
    Clipboard.setData(
      ClipboardData(text: '$cleanUrl:${p.username}:${p.password}'),
    );
    ForjaToast.success(
      'Portal details copied to clipboard',
      duration: const Duration(seconds: 2),
    );
  }

  PlayerSourceStatus _activePortalStatus({
    required bool checking,
    required bool? health,
  }) {
    if (checking) return PlayerSourceStatus.checking;
    if (health == false) return PlayerSourceStatus.failed;
    return PlayerSourceStatus.active;
  }

  Widget _activePortalStatusGlyph(PlayerSourceStatus status) {
    final color = playerSourceStatusColor(status);
    final Widget glyph = switch (status) {
      PlayerSourceStatus.active => Icon(
          Icons.play_circle_filled_rounded,
          color: color,
          size: _statusSlot,
        ),
      PlayerSourceStatus.failed => Icon(
          Icons.cancel_rounded,
          color: color,
          size: _statusSlot,
        ),
      PlayerSourceStatus.checking => SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
      PlayerSourceStatus.ready => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
    };
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(child: glyph),
    );
  }

  Widget _idlePortalHealthDot({
    required bool checking,
    required bool? health,
  }) {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(
        child: checking
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white54,
                ),
              )
            : Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: health == true
                      ? playerSourceStatusColor(PlayerSourceStatus.active)
                      : health == false
                      ? playerSourceStatusColor(PlayerSourceStatus.failed)
                      : playerSourceStatusColor(PlayerSourceStatus.ready),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final v = widget.portal;
    final isActive = widget.isActive;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final isFav = ctrl.isFavoritePortal(v.key);
        final health = ctrl.portalHealthFor(v.key);
        final checking = ctrl.isPortalHealthChecking(v.key);
        final title = v.name.trim().isEmpty
            ? (v.portal.username.trim().isEmpty ? 'Portal' : v.portal.username)
            : v.name.trim();

        return LayoutBuilder(
          builder: (context, constraints) {
            return MouseRegion(
              onEnter: (_) {
                setState(() => _lineHover = true);
                _armRevealTimer();
                ctrl.schedulePortalHealthCheck(v);
              },
              onExit: (_) {
                _clearHover();
                ctrl.cancelPortalHealthCheck(v.key);
              },
              onHover: (event) {
                final w = constraints.maxWidth;
                if (w <= 0) return;
                if (event.localPosition.dx >= w * (1 - _rightHotFraction)) {
                  _openActions();
                }
              },
              child: ColoredBox(
                color: isActive
                    ? playerSourceStatusColor(
                        PlayerSourceStatus.active,
                      ).withValues(alpha: 0.07)
                    : (_lineHover || _focused)
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: iptvTap(
                          context: context,
                          onTap: () => ctrl.selectPortal(v),
                          borderRadius: 0,
                          listIndex: widget.listIndex,
                          tvRowId: 'portals',
                          tvItemIndex: widget.listIndex,
                          onFocusChange: (focused) {
                            setState(() {
                              _focused = focused;
                              if (focused) {
                                _actionsOpen = true;
                              } else if (!_lineHover) {
                                _actionsOpen = false;
                              }
                            });
                            if (focused) {
                              ctrl.schedulePortalHealthCheck(v);
                            } else {
                              ctrl.cancelPortalHealthCheck(v.key);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                isActive
                                    ? _activePortalStatusGlyph(
                                        _activePortalStatus(
                                          checking: checking,
                                          health: health,
                                        ),
                                      )
                                    : _idlePortalHealthDot(
                                        checking: checking,
                                        health: health,
                                      ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.88,
                                                ),
                                          fontSize: 13,
                                          fontWeight: isActive
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          height: 1.15,
                                        ),
                                      ),
                                      Text(
                                        v.portal.url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white38,
                                          fontSize: 11,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                iptvTap(
                                  context: context,
                                  onTap: () => ctrl.toggleFavoritePortal(v.key),
                                  borderRadius: 16,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      isFav
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 16,
                                      color: isFav
                                          ? const Color(0xFFFBBF24)
                                          : Colors.white30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        width: _reveal ? _actionW : 0,
                        height: 48,
                        child: ClipRect(
                          child: OverflowBox(
                            minWidth: _actionW,
                            maxWidth: _actionW,
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: _actionW,
                              height: 48,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _railAction(
                                    tooltip: 'Copy',
                                    icon: Icons.copy_rounded,
                                    color: Colors.white60,
                                    onTap: _copy,
                                  ),
                                  _railAction(
                                    tooltip: 'Edit',
                                    icon: Icons.edit_rounded,
                                    color: Colors.white60,
                                    onTap: widget.onEdit,
                                  ),
                                  _railAction(
                                    tooltip: 'Delete',
                                    icon: Icons.delete_rounded,
                                    color: const Color(0xFFEF4444),
                                    onTap: () => ctrl.deletePortal(v.key),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _railAction({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
