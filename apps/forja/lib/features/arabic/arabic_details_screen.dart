import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/extractors/arabic_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'arabic_player_screen.dart';

class ArabicDetailsScreen extends StatefulWidget {
  final ArabicShow show;

  const ArabicDetailsScreen({super.key, required this.show});

  @override
  State<ArabicDetailsScreen> createState() => _ArabicDetailsScreenState();
}

class _ArabicDetailsScreenState extends State<ArabicDetailsScreen> {
  final ArabicService _service = ArabicService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'arabic-details-play');

  ArabicShowDetail? _detail;
  bool _isLoading = true;
  bool _isLiked = false;
  int _selectedSeason = 0;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadLikedStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroPlayFocus.dispose();
    super.dispose();
  }

  void _revealedDetailsHeroPlayFocus() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadDetails() async {
    final ArabicShowDetail detail;
    if (widget.show.source == 'dimatoon') {
      detail = await _service.getDimaToonDetails(widget.show.url);
    } else if (widget.show.source == 'brstej') {
      detail = await _service.getBrstejDetails(widget.show.id);
    } else {
      detail = await _service.getShowDetails(widget.show.id);
    }
    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLikedStatus() async {
    final liked = await _service.isLiked(widget.show.id);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    await _service.toggleLike(widget.show);
    _loadLikedStatus();
  }

  void _playEpisode(ArabicEpisode episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArabicPlayerScreen(
          videoId: episode.id,
          title: episode.title,
          source: widget.show.source,
        ),
      ),
    );
  }

  bool get _tvNav => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildShowInfo(),
                  const SizedBox(height: 24),
                  if (_detail?.description.isNotEmpty == true) ...[
                    _buildDescription(),
                    const SizedBox(height: 24),
                  ],
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryColor),
                    )
                  else if (_detail != null && _detail!.seasons.isNotEmpty) ...[
                    if (_detail!.seasons.length > 1) _buildSeasonTabs(),
                    const SizedBox(height: 16),
                    _buildEpisodesList(),
                  ] else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text(
                          'لا توجد حلقات',
                          style: TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!_tvNav) return body;

    return MediaDetailsTvScope(
      heroPlayFocus: _heroPlayFocus,
      scrollController: _scrollController,
      child: body,
    );
  }

  Widget _buildAppBar() {
    final poster = _detail?.poster ?? widget.show.poster;
    return SliverAppBar(
      expandedHeight:
          MediaQuery.of(context).orientation == Orientation.landscape ? 200 : 300,
      pinned: true,
      backgroundColor: AppTheme.bgDark,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.redAccent : Colors.white,
          ),
          onPressed: _toggleLike,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (poster.isNotEmpty)
              CachedNetworkImage(
                imageUrl: poster,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(color: AppTheme.bgDark),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.bgDark.withValues(alpha: 0.6),
                    AppTheme.bgDark,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowInfo() {
    final title = _detail?.title ?? widget.show.title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 100,
            height: 140,
            child: widget.show.poster.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.show.poster,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Icon(Icons.movie_outlined, color: Colors.white24),
                    ),
                  )
                : Container(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Icon(Icons.movie_outlined, color: Colors.white24),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_detail != null && _detail!.seasons.isNotEmpty)
                Text(
                  '${_detail!.seasons.length} مواسم',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'القصة',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _detail!.description,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSeasonTabs() {
    final tv = _tvNav;
    if (tv) {
      shellTvRegisterRow(
        tabId: MediaDetailsTv.tabId,
        rowId: 'seasons',
        sortOrder: 0,
        itemCount: _detail!.seasons.length,
        onFocusUp: _revealedDetailsHeroPlayFocus,
      );
    }

    return SizedBox(
      height: 44,
      child: NotificationListener<ScrollNotification>(
        onNotification: shellAbsorbHorizontalScroll,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          reverse: true,
          itemCount: _detail!.seasons.length,
          itemBuilder: (context, index) {
            final season = _detail!.seasons[index];
            final isSelected = _selectedSeason == index;
            final chip = Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.white12,
                ),
              ),
              child: Text(
                'الموسم ${season.number}',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            );

            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: tv
                  ? shellFocusableTap(
                      context: context,
                      onTap: () => setState(() => _selectedSeason = index),
                      borderRadius: 12,
                      tvTabId: MediaDetailsTv.tabId,
                      tvRowId: 'seasons',
                      tvItemIndex: index,
                      child: chip,
                    )
                  : GestureDetector(
                      onTap: () => setState(() => _selectedSeason = index),
                      child: chip,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEpisodesList() {
    if (_detail == null || _detail!.seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    final season = _detail!.seasons[_selectedSeason];
    final episodes = season.episodes;
    final hasSeasons = _detail!.seasons.length > 1;
    final tv = _tvNav;

    if (episodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text(
            'لا توجد حلقات في هذا الموسم',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    if (tv) {
      shellTvRegisterRow(
        tabId: MediaDetailsTv.tabId,
        rowId: 'episodes',
        sortOrder: hasSeasons ? 1 : 0,
        itemCount: episodes.length,
        orientation: ShellTvRowOrientation.vertical,
        onFocusUp: hasSeasons ? null : _revealedDetailsHeroPlayFocus,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${episodes.length} حلقة',
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final episode = episodes[index];
            return _EpisodeTile(
              episode: episode,
              onTap: () => _playEpisode(episode),
              tvTabId: tv ? MediaDetailsTv.tabId : null,
              tvRowId: tv ? 'episodes' : null,
              tvItemIndex: tv ? index : null,
            );
          },
        ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.onTap,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
  });

  final ArabicEpisode episode;
  final VoidCallback onTap;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          if (episode.poster.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 50,
                child: CachedNetworkImage(
                  imageUrl: episode.poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(color: Colors.white10),
                ),
              ),
            ),
          if (episode.poster.isNotEmpty) const SizedBox(width: 12),
          Expanded(
            child: Text(
              episode.title,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const Icon(Icons.chevron_left, color: Colors.white24, size: 20),
        ],
      ),
    );

    if (tvTabId == null) {
      return InkWell(onTap: onTap, child: content);
    }

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 8,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      child: content,
    );
  }
}
