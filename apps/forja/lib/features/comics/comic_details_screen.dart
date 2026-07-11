import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'comic_reader_screen.dart';
import 'package:forja/features/comics/catalog/comics_service.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

class ComicDetailsScreen extends StatefulWidget {
  final Comic comic;
  const ComicDetailsScreen({super.key, required this.comic});

  @override
  State<ComicDetailsScreen> createState() => _ComicDetailsScreenState();
}

class _ComicDetailsScreenState extends State<ComicDetailsScreen> {
  final ComicsService _comicsService = ComicsService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'comic-details-play');

  ComicDetails? _details;
  bool _isLoading = true;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _checkLikeStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroPlayFocus.dispose();
    super.dispose();
  }

  bool get _tvNav => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  Future<void> _loadDetails() async {
    final details = await _comicsService.getComicDetails(widget.comic);
    if (mounted) {
      setState(() {
        _details = details;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLikeStatus() async {
    final liked = await _comicsService.isLiked(widget.comic.url);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    await _comicsService.toggleLike(widget.comic);
    _checkLikeStatus();
  }

  void _openChapter(int index) {
    final chapter = _details!.chapters[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComicReaderScreen(
          chapterTitle: chapter.title,
          chapterUrl: chapter.url,
          chapters: _details!.chapters,
          currentChapterIndex: index,
          comic: widget.comic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_details == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: const Center(
          child: Text(
            'Failed to load details',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainInfo(),
                  const SizedBox(height: 32),
                  _buildSummary(),
                  const SizedBox(height: 32),
                  const Text(
                    'CHAPTERS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildChaptersList(),
                  const SizedBox(height: 100),
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
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.bgDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.comic.title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.redAccent : Colors.white,
          ),
          onPressed: _toggleLike,
        ),
      ],
    );
  }

  Widget _buildMainInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: widget.comic.poster,
            width: 120,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.comic.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_details!.otherName != 'None' &&
                  _details!.otherName != widget.comic.title)
                Text(
                  _details!.otherName,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _details!.genres.map(_buildGenreChip).toList(),
              ),
              const SizedBox(height: 16),
              _buildMetaItem(Icons.business, 'Publisher', _details!.publisher),
              _buildMetaItem(Icons.edit, 'Writer', _details!.writer),
              _buildMetaItem(Icons.palette, 'Artist', _details!.artist),
              _buildMetaItem(
                Icons.calendar_today,
                'Published',
                _details!.publicationDate,
              ),
              _buildMetaItem(
                Icons.info_outline,
                'Status',
                widget.comic.status,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenreChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaItem(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    if (value == 'Unknown' || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SUMMARY',
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.comic.summary,
          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildChaptersList() {
    final tv = _tvNav;

    if (tv) {
      shellTvRegisterRow(
        tabId: MediaDetailsTv.tabId,
        rowId: 'chapters',
        sortOrder: 0,
        itemCount: _details!.chapters.length,
        orientation: ShellTvRowOrientation.vertical,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _details!.chapters.length,
      separatorBuilder: (_, _) =>
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
      itemBuilder: (context, index) {
        final chapter = _details!.chapters[index];
        final tile = ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book, color: AppTheme.primaryColor, size: 20),
          ),
          title: Text(
            chapter.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            chapter.dateAdded,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          onTap: tv ? null : () => _openChapter(index),
        );

        if (!tv) return tile;

        return shellFocusableTap(
          context: context,
          onTap: () => _openChapter(index),
          borderRadius: 8,
          tvTabId: MediaDetailsTv.tabId,
          tvRowId: 'chapters',
          tvItemIndex: index,
          child: tile,
        );
      },
    );
  }
}
