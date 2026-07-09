import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:rust/rust.dart';

class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.label,
    this.accent = false,
    this.color,
  });

  final String label;
  final bool accent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color ??
            (accent
                ? ForjaShellColors.chipSelectedBg
                : Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: accent
              ? ForjaShellColors.chipSelectedBorder
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent
              ? ForjaShellColors.cinematic.textPrimary
              : ForjaShellColors.cinematic.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SourceMetadataRow extends StatelessWidget {
  const SourceMetadataRow({super.key, required this.metadata});

  final TorrentReleaseMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final flags = metadata.flags;
    final badges = metadata.badgeLabels;
    if (flags.isEmpty && badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (flags.isNotEmpty)
          Text(
            flags,
            style: const TextStyle(fontSize: 14, height: 1.1),
          ),
        ...badges.map((b) => SourceBadge(label: b, accent: b == metadata.quality)),
      ],
    );
  }
}

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
    final metadata = TorrentReleaseMetadata.parse(result.name);

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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SourceMetadataRow(metadata: metadata),
                        if (metadata.badgeLabels.isNotEmpty || metadata.flags.isNotEmpty)
                          const SizedBox(height: 6),
                        if (isResumable)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'RESUME',
                              style: TextStyle(
                                color: ForjaShellColors.cinematic.textPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        Text(
                          result.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 11,
                                  color: Color(0xFF22C55E),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  result.seeders,
                                  style: const TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              result.size,
                              style: TextStyle(
                                color: ForjaShellColors.cinematic.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            if (trackerName.isNotEmpty)
                              Text(
                                trackerName,
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 11,
                                ),
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

class WebstreamingSourceTile extends StatelessWidget {
  const WebstreamingSourceTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPlay,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final metadata = TorrentReleaseMetadata.parse(title);

    return FocusableControl(
      onTap: onPlay,
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SourceMetadataRow(metadata: metadata),
                    if (metadata.badgeLabels.isNotEmpty || metadata.flags.isNotEmpty)
                      const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ForjaShellColors.cinematic.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: ForjaShellColors.cinematic.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _iconBtn(Icons.play_arrow_rounded, true, onPlay),
            ],
          ),
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
    final metadata = TorrentReleaseMetadata.parse('$title $description');

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isExternal)
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 2),
                      child: Icon(leadingIcon, color: leadingColor, size: 24),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isExternal) SourceMetadataRow(metadata: metadata),
                        if (!isExternal &&
                            (metadata.badgeLabels.isNotEmpty || metadata.flags.isNotEmpty))
                          const SizedBox(height: 6),
                        if (isResumable && !isExternal)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'RESUME',
                              style: TextStyle(
                                color: ForjaShellColors.cinematic.textPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textPrimary,
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
                            style: TextStyle(
                              color: ForjaShellColors.cinematic.textSecondary,
                              fontSize: 11,
                            ),
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

Widget _iconBtn(IconData icon, bool highlight, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: highlight ? ForjaShellColors.chipSelectedBg : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight
                ? ForjaShellColors.chipSelectedBorder
                : ForjaShellColors.cinematic.borderSubtle,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: highlight
              ? ForjaShellColors.chipSelectedIcon
              : ForjaShellColors.cinematic.textSecondary,
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
