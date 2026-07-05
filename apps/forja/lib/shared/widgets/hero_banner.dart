import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:forja_core/models/movie.dart';
import 'package:forja_api/api/tmdb_api.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja_core/utils/extensions.dart';

class HeroBanner extends StatefulWidget {
  final List<Movie> movies;

  const HeroBanner({super.key, required this.movies});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  int _currentIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    final heroHeight = isMobile ? screenHeight * 0.6 : screenHeight * 0.75;
    final featuredMovies = widget.movies.take(5).toList();

    return Focus(
      child: Stack(
        children: [
          CarouselSlider(
            carouselController: _carouselController,
            options: CarouselOptions(
              height: heroHeight,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 8),
              autoPlayAnimationDuration: const Duration(milliseconds: 1000),
              autoPlayCurve: Curves.fastOutSlowIn,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            items: featuredMovies.map((movie) {
              final imageUrl = TmdbApi.getBackdropUrl(movie.backdropPath);
              return InkWell(
                onTap: () => _navigateToDetails(movie),
                focusColor: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. High-Res Background
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Container(color: const Color(0xFF0F0418)),
                      errorWidget: (context, url, error) => Container(color: const Color(0xFF0F0418)),
                    ),
                    
                    // 2. Cinematic Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0F0418).withValues(alpha: 0.2),
                            const Color(0xFF0F0418).withValues(alpha: 0.8),
                            const Color(0xFF0F0418),
                          ],
                          stops: const [0.0, 0.4, 0.8, 1.0],
                        ),
                      ),
                    ),

                    // 3. Side Gradient for text readability (Desktop)
                    if (!isMobile)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFF0F0418).withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

        // Content
        Positioned(
          bottom: 40,
          left: isMobile ? 24 : 60,
          right: isMobile ? 24 : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              SizedBox(
                width: isMobile ? null : screenWidth * 0.5,
                child: Text(
                  featuredMovies[_currentIndex].title,
                  style: TextStyle(
                    fontSize: isMobile ? 32 : 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        blurRadius: 20.0,
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              
              // Metadata
              Row(
                children: [
                  _buildBadge(
                    'TMDB ${featuredMovies[_currentIndex].voteAverage.toStringAsFixed(1)}', 
                    Colors.amber, 
                    Icons.star
                  ),
                  const SizedBox(width: 12),
                  _buildBadge(
                    featuredMovies[_currentIndex].releaseDate.take(4), 
                    Colors.white70, 
                    Icons.calendar_today
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _navigateToDetails(featuredMovies[_currentIndex]),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('Play Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                      shadowColor: Colors.deepPurpleAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {}, // TODO: Add to list
                    icon: const Icon(Icons.add_rounded, size: 24),
                    label: const Text('My List'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Indicators
        Positioned(
          bottom: 20,
          right: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: featuredMovies.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () => _carouselController.animateToPage(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentIndex == entry.key ? 24.0 : 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == entry.key 
                        ? Colors.deepPurpleAccent 
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetails(Movie movie) async {
    if (!mounted) return;
    await AppRouter.openMovie(context, movie: movie);
  }
}


