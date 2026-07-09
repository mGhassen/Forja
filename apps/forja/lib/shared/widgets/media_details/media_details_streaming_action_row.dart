import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:rust/rust.dart';

/// Play / My List actions on streaming details hero with extraction state.
class MediaDetailsStreamingActionRow extends StatelessWidget {
  const MediaDetailsStreamingActionRow({
    super.key,
    required this.movie,
    required this.hasResume,
    required this.isExtracting,
    required this.onPlay,
    this.statusMessage,
  });

  final Movie movie;
  final bool hasResume;
  final bool isExtracting;
  final VoidCallback? onPlay;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isExtracting)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            HeroPillPlayButton(
              label: isExtracting ? 'Loading' : (hasResume ? 'Resume' : 'Play'),
              icon: isExtracting ? null : Icons.play_arrow_rounded,
              onTap: isExtracting ? null : onPlay,
            ),
            const SizedBox(width: 10),
            HeroPillIconGroup(
              slots: [
                HeroPillIconSlot(
                  child: MyListButton.movie(
                    movie: movie,
                    iconColor: Colors.white,
                    iconColorActive: Colors.white,
                    iconSize: 20,
                  ),
                  tooltip: 'Add to My List',
                ),
              ],
            ),
          ],
        ),
        if (isExtracting && statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            statusMessage!,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ],
    );
  }
}
