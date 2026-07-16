part of 'iptv_pt_screen.dart';

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
            title: ctrl.activePortal?.displayLabel ?? 'Portal',
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
