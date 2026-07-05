import 'package:flutter/material.dart';
import 'theme.dart';

class ForjaPosterCard extends StatefulWidget {
  const ForjaPosterCard({
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
  State<ForjaPosterCard> createState() => _ForjaPosterCardState();
}

class _ForjaPosterCardState extends State<ForjaPosterCard> {
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
                          errorBuilder: (_, __, ___) => _placeholder())
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
                  color: ForjaTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: ForjaTheme.bgCard,
        child: const Center(
          child: Icon(Icons.movie_outlined, color: ForjaTheme.textSecondary),
        ),
      );
}
