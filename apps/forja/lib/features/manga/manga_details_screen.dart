import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:api/api/manga_service.dart';
import 'manga_reader_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';

class MangaDetailsScreen extends StatefulWidget {
  final Manga manga;

  const MangaDetailsScreen({super.key, required this.manga});

  @override
  State<MangaDetailsScreen> createState() => _MangaDetailsScreenState();
}

class _MangaDetailsScreenState extends State<MangaDetailsScreen> {
  final MangaService _mangaService = MangaService();
  final TextEditingController _chapterSearchController = TextEditingController();
  bool _isLiked = false;
  bool _isLoadingChapters = true;
  List<MangaChapter> _chapters = [];
  int _currentChapterPage = 0;
  static const int _chaptersPerPage = 20;
  Manga? _fullManga;

  Manga get _manga => _fullManga ?? widget.manga;

  @override
  void initState() {
    super.initState();
    _loadLikedStatus();
    _loadDetails();
    _loadChapters();
  }

  @override
  void dispose() {
    _chapterSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadLikedStatus() async {
    final liked = await _mangaService.isLiked(widget.manga.id);
    if (mounted) {
      setState(() => _isLiked = liked);
    }
  }

  Future<void> _loadDetails() async {
    try {
      final detail = await _mangaService.getSeriesDetail(widget.manga.id);
      if (mounted) setState(() => _fullManga = detail);
    } catch (e) {
      debugPrint('[MangaDetails] Error loading details: $e');
    }
  }

  Future<void> _loadChapters() async {
    final chapters = await _mangaService.getChapters(widget.manga.id);
    if (mounted) {
      setState(() {
        _chapters = chapters;
        _isLoadingChapters = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    await _mangaService.toggleLike(widget.manga);
    _loadLikedStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
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
        _manga.title,
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
            imageUrl: _manga.coverNormal,
            width: 120,
            height: 180,
            fit: BoxFit.cover,
            errorWidget: (c, u, e) => Container(
              width: 120,
              height: 180,
              color: Colors.white10,
              child: const Icon(Icons.broken_image, color: Colors.white24),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _manga.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _buildMetaItem(Icons.calendar_today, 'Year', _manga.year),
              _buildMetaItem(Icons.category, 'Type', _manga.type.toUpperCase()),
              _buildMetaItem(Icons.info_outline, 'Status', _manga.status.toUpperCase(), color: AppTheme.primaryColor),
              _buildMetaItem(Icons.person, 'Author', _manga.author),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, {Color? color}) {
    if (value.isEmpty || value == '0') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
          'SYNOPSIS',
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _manga.synopsis,
          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildChaptersList() {
    if (_isLoadingChapters) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }
    
    if (_chapters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No chapters available', style: TextStyle(color: Colors.white54)),
        ),
      );
    }
    
    final startIndex = _currentChapterPage * _chaptersPerPage;
    final endIndex = (startIndex + _chaptersPerPage).clamp(0, _chapters.length);
    final displayedChapters = _chapters.sublist(startIndex, endIndex);
    final totalPages = (_chapters.length / _chaptersPerPage).ceil();
    
    return Column(
      children: [
        // Chapter search/jump
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chapterSearchController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Jump to chapter...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _jumpToChapter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Go',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Chapters list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: displayedChapters.length,
          separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          itemBuilder: (context, index) {
            final actualIndex = startIndex + index;
            final chapter = displayedChapters[index];
            final chapterTitle = chapter.name.isNotEmpty 
                ? 'Chapter ${chapter.number} - ${chapter.name}' 
                : 'Chapter ${chapter.number}';
            
            return ListTile(
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
                chapterTitle,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: chapter.name.isNotEmpty
                  ? Text(
                      chapter.name,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    )
                  : null,
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MangaReaderScreen(
                      manga: _manga,
                      chapters: _chapters,
                      currentChapterIndex: actualIndex,
                    ),
                  ),
                );
              },
            );
          },
        ),
        
        // Pagination controls
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _currentChapterPage > 0 ? _prevChapterPage : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                disabledForegroundColor: Colors.white24,
              ),
            ),
            Text(
              'Page ${_currentChapterPage + 1} of $totalPages',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _currentChapterPage < totalPages - 1 ? _nextChapterPage : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                disabledForegroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _jumpToChapter() {
    final input = _chapterSearchController.text.trim();
    if (input.isEmpty) return;
    
    final chapterNumber = double.tryParse(input);
    if (chapterNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid chapter number')),
      );
      return;
    }
    
    // Find the chapter index
    final chapterIndex = _chapters.indexWhere((ch) => ch.number == chapterNumber);
    
    if (chapterIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chapter $chapterNumber not found')),
      );
      return;
    }
    
    // Calculate which page this chapter is on
    final targetPage = chapterIndex ~/ _chaptersPerPage;
    
    setState(() {
      _currentChapterPage = targetPage;
    });
    
    _chapterSearchController.clear();
  }

  void _nextChapterPage() {
    setState(() {
      _currentChapterPage++;
    });
  }

  void _prevChapterPage() {
    setState(() {
      _currentChapterPage--;
    });
  }
}
