part of 'iptv_pt_screen.dart';

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
