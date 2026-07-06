import 'package:flutter/material.dart';
import 'package:core/models/movie.dart';
import 'package:storage/storage.dart';
import 'movie_poster.dart';
import 'package:forja/shared/theme/app_theme.dart';

class MovieSection extends StatefulWidget {
  final String title;
  final List<Movie> movies;

  const MovieSection({super.key, required this.title, required this.movies});

  @override
  State<MovieSection> createState() => _MovieSectionState();
}

class _MovieSectionState extends State<MovieSection> {
  final ScrollController _controller = ScrollController();
  final double _scrollAmount = 400.0; // Adjusted for wider cards

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    if (_controller.hasClients) {
      final target = (_controller.offset - _scrollAmount).clamp(
        0.0,
        _controller.position.maxScrollExtent,
      );
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic, // Smoother curve
      );
    }
  }

  void _scrollRight() {
    if (_controller.hasClients) {
      final target = (_controller.offset + _scrollAmount).clamp(
        0.0,
        _controller.position.maxScrollExtent,
      );
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24.0, top: 24.0, bottom: 12.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: AppTheme.isLightMode ? null : [
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 450, // Increased height for larger cards + scale
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: widget.movies.length,
                padding: const EdgeInsets.symmetric(horizontal: 48),
                clipBehavior: Clip.none,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 220,
                    child: MoviePoster(movie: widget.movies[index]),
                  );
                },
              ),
              // Left Arrow with Glow
              Positioned(
                left: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                      boxShadow: AppTheme.isLightMode ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
                      onPressed: _scrollLeft,
                      tooltip: 'Scroll Left',
                    ),
                  ),
                ),
              ),
              // Right Arrow with Glow
              Positioned(
                right: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                      boxShadow: AppTheme.isLightMode ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28),
                      onPressed: _scrollRight,
                      tooltip: 'Scroll Right',
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
