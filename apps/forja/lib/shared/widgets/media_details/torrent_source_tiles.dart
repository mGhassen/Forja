import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';

class TorrentSourceTile extends StatelessWidget {
  const TorrentSourceTile({
    super.key,
    required this.result,
    required this.trackerName,
    required this.onPlay,
    required this.onCopyMagnet,
    this.progress = 0,
    this.isResumable = false,
    this.highlightStart = false,
  });

  final TorrentResult result;
  final String trackerName;
  final VoidCallback onPlay;
  final VoidCallback onCopyMagnet;
  final double progress;
  final bool isResumable;
  final bool highlightStart;

  @override
  Widget build(BuildContext context) {
    final n = result.name.toUpperCase();
    String quality = '?';
    Color qColor = Colors.grey;
    if (n.contains('2160') || n.contains('4K') || n.contains('UHD')) {
      quality = '4K';
      qColor = const Color(0xFF7C3AED);
    } else if (n.contains('1080')) {
      quality = '1080p';
      qColor = const Color(0xFF1D4ED8);
    } else if (n.contains('720')) {
      quality = '720p';
      qColor = const Color(0xFF0369A1);
    } else if (n.contains('480')) {
      quality = '480p';
      qColor = Colors.grey.shade700;
    }

    String? codec;
    if (n.contains('HEVC') || n.contains('X265') || n.contains('H.265')) {
      codec = 'HEVC';
    } else if (n.contains('X264') || n.contains('H.264') || n.contains('H264') || n.contains('AVC')) {
      codec = 'h264';
    } else if (n.contains('AV1')) {
      codec = 'AV1';
    }

    return FocusableControl(
      onTap: onPlay,
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: (isResumable || highlightStart)
              ? ForjaShellColors.chipSelectedBg
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isResumable
                ? ForjaShellColors.chipSelectedBorder
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _qualityBadge(quality, qColor),
                        if (codec != null) ...[
                          const SizedBox(height: 4),
                          _codecBadge(codec),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isResumable)
                          Text(
                            'RESUME',
                            style: TextStyle(
                              color: ForjaShellColors.textPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        Text(
                          result.name,
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_upward_rounded,
                                    size: 11, color: Color(0xFF22C55E)),
                                const SizedBox(width: 2),
                                Text(
                                  result.seeders,
                                  style: const TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              result.size,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            if (trackerName.isNotEmpty)
                              Text(
                                trackerName,
                                style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _iconBtn(Icons.content_copy_rounded, false, onCopyMagnet),
                      const SizedBox(height: 6),
                      _iconBtn(Icons.play_arrow_rounded, true, onPlay),
                    ],
                  ),
                ],
              ),
            ),
            if (isResumable && progress > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    color: ForjaShellColors.progressFill,
                    minHeight: 2.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StremioSourceTile extends StatelessWidget {
  const StremioSourceTile({
    super.key,
    required this.title,
    required this.description,
    required this.leadingIcon,
    required this.leadingColor,
    required this.actionIcon,
    required this.onTap,
    this.addonName,
    this.showAddonName = false,
    this.progress = 0,
    this.isResumable = false,
    this.isExternal = false,
    this.highlightStart = false,
  });

  final String title;
  final String description;
  final IconData leadingIcon;
  final Color leadingColor;
  final IconData actionIcon;
  final VoidCallback onTap;
  final String? addonName;
  final bool showAddonName;
  final double progress;
  final bool isResumable;
  final bool isExternal;
  final bool highlightStart;

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      onTap: onTap,
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: isExternal
              ? leadingColor.withValues(alpha: 0.06)
              : ((isResumable || highlightStart)
                  ? ForjaShellColors.chipSelectedBg
                  : Colors.white.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isExternal
                ? leadingColor.withValues(alpha: 0.25)
                : (isResumable
                    ? ForjaShellColors.chipSelectedBorder
                    : Colors.white.withValues(alpha: 0.07)),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(leadingIcon, color: leadingColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isResumable && !isExternal)
                          Text(
                            'RESUME',
                            style: TextStyle(
                              color: ForjaShellColors.textPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        if (addonName != null && showAddonName)
                          Text(
                            addonName!,
                            style: TextStyle(
                              color: leadingColor.withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        Text(
                          title,
                          maxLines: 4,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _iconBtn(actionIcon, true, onTap),
                ],
              ),
            ),
            if (isResumable && progress > 0 && !isExternal)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    color: ForjaShellColors.progressFill,
                    minHeight: 2.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _qualityBadge(String q, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
      child: Text(
        q,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );

Widget _codecBadge(String codec) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        codec,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

Widget _iconBtn(IconData icon, bool highlight, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: highlight ? ForjaShellColors.chipSelectedBg : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight ? ForjaShellColors.chipSelectedBorder : Colors.white12,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: highlight ? ForjaShellColors.iconActive : Colors.white54,
        ),
      ),
    );

StremioTilePresentation stremioTilePresentation(Map<String, dynamic> stream, {required bool isResumable}) {
  final externalUrl = stream['externalUrl']?.toString();
  final isExternal = externalUrl != null && externalUrl.isNotEmpty;
  final isStremioLink = isExternal && externalUrl.startsWith('stremio://');
  final isWebLink =
      isExternal && (externalUrl.startsWith('http://') || externalUrl.startsWith('https://'));

  IconData leadingIcon;
  Color leadingColor;
  IconData actionIcon;
  if (isStremioLink) {
    final parsed = StremioService.parseMetaLink(externalUrl);
    final action = parsed?['action'];
    if (action == 'detail') {
      leadingIcon = Icons.movie_outlined;
      leadingColor = Colors.amberAccent;
      actionIcon = Icons.open_in_new_rounded;
    } else if (action == 'search') {
      leadingIcon = Icons.search_rounded;
      leadingColor = Colors.cyanAccent;
      actionIcon = Icons.search_rounded;
    } else {
      leadingIcon = Icons.explore_outlined;
      leadingColor = Colors.tealAccent;
      actionIcon = Icons.open_in_new_rounded;
    }
  } else if (isWebLink) {
    leadingIcon = Icons.language_rounded;
    leadingColor = Colors.lightBlueAccent;
    actionIcon = Icons.open_in_browser_rounded;
  } else if (isResumable) {
    leadingIcon = Icons.play_circle_filled_rounded;
    leadingColor = ForjaShellColors.textPrimary;
    actionIcon = Icons.play_arrow_rounded;
  } else {
    leadingIcon = Icons.extension_rounded;
    leadingColor = Colors.blueAccent;
    actionIcon = Icons.play_arrow_rounded;
  }

  return StremioTilePresentation(
    leadingIcon: leadingIcon,
    leadingColor: leadingColor,
    actionIcon: actionIcon,
    isExternal: isExternal,
  );
}

class StremioTilePresentation {
  const StremioTilePresentation({
    required this.leadingIcon,
    required this.leadingColor,
    required this.actionIcon,
    required this.isExternal,
  });

  final IconData leadingIcon;
  final Color leadingColor;
  final IconData actionIcon;
  final bool isExternal;
}
