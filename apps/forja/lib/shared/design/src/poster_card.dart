import 'package:flutter/material.dart';
import 'theme.dart';

class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.onTap,
    this.aspectRatio = 2 / 3,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double aspectRatio;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1,
          duration: const Duration(milliseconds: 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? Image.network(widget.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder())
                      : _placeholder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: DesignTokens.bgCard,
        child: const Center(
          child: Icon(Icons.movie_outlined, color: DesignTokens.textSecondary),
        ),
      );
}
