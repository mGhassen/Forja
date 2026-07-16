part of 'iptv_pt_screen.dart';

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
                      style: GoogleFonts.plusJakartaSans(color: Colors.white60),
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
                sources: [IptvPlaySource(url: url, label: p.displayLabel)],
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
                      style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
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
