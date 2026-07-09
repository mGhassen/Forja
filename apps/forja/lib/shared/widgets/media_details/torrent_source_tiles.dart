import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:rust/rust.dart';

class TorrentSourceTile extends StatelessWidget {
  const TorrentSourceTile({
    super.key,
    required this.result,
    required this.onPlay,
    this.progress = 0,
    this.isResumable = false,
    this.highlightStart = false,
  });

  final TorrentResult result;
  final VoidCallback onPlay;
  final double progress;
  final bool isResumable;
  final bool highlightStart;

  @override
  Widget build(BuildContext context) {
    final isTv = ShellTokens.isTvLayout(context);
    final metadata = TorrentReleaseMetadata.parse(result.name);
    final quality = metadata.quality ?? '?';
    final meta = metadata.compactMetaLine;
    final titleSize = isTv ? 15.0 : 13.0;
    final padV = isTv ? 14.0 : 10.0;
    final seeds = result.seedersCount > 0
        ? '${result.seedersCount}'
        : (result.seeders.trim().isEmpty ? '0' : result.seeders.trim());
    final hasSeeds = result.seedersCount > 0 ||
        (int.tryParse(result.seeders.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) > 0;

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
              padding: EdgeInsets.fromLTRB(12, padV, 12, padV),
              child: Row(
                children: [
                  SizedBox(
                    width: isTv ? 56 : 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quality,
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textPrimary,
                            fontSize: isTv ? 13 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          seeds,
                          style: TextStyle(
                            color: hasSeeds
                                ? const Color(0xFF22C55E)
                                : ForjaShellColors.cinematic.textSecondary,
                            fontSize: isTv ? 15 : 13,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        Text(
                          'seeds',
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textSecondary,
                            fontSize: isTv ? 10 : 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (result.size.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            result.size.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ForjaShellColors.cinematic.textSecondary,
                              fontSize: isTv ? 11 : 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isResumable)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              'RESUME',
                              style: TextStyle(
                                color: ForjaShellColors.cinematic.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        Text(
                          result.name,
                          maxLines: isTv ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textPrimary,
                            fontSize: titleSize,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ForjaShellColors.cinematic.textSecondary,
                              fontSize: isTv ? 12 : 11,
                            ),
                          ),
                        ],
                      ],
                    ),
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
    final isTv = ShellTokens.isTvLayout(context);
    final meta = TorrentReleaseMetadata.parse(title).compactMetaLine;

    return FocusableControl(
      onTap: onPlay,
      borderRadius: 10,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isTv ? 14 : 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: isTv ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textPrimary,
                      fontSize: isTv ? 15 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (meta.isNotEmpty || subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (meta.isNotEmpty) meta, if (subtitle != null) subtitle]
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ForjaShellColors.cinematic.textSecondary,
                        fontSize: isTv ? 12 : 11,
                      ),
                    ),
                  ],
                ],
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
  final VoidCallback onTap;
  final String? addonName;
  final bool showAddonName;
  final double progress;
  final bool isResumable;
  final bool isExternal;
  final bool highlightStart;

  @override
  Widget build(BuildContext context) {
    final isTv = ShellTokens.isTvLayout(context);
    final meta = isExternal
        ? ''
        : TorrentReleaseMetadata.parse('$title $description').compactMetaLine;

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
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: isTv ? 14 : 10),
              child: Row(
                children: [
                  if (isExternal)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(leadingIcon, color: leadingColor, size: isTv ? 26 : 22),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isResumable && !isExternal)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              'RESUME',
                              style: TextStyle(
                                color: ForjaShellColors.cinematic.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (addonName != null && showAddonName)
                          Text(
                            addonName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: leadingColor.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          title,
                          maxLines: isTv ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textPrimary,
                            fontSize: isTv ? 15 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (meta.isNotEmpty || description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta.isNotEmpty ? meta : description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ForjaShellColors.cinematic.textSecondary,
                              fontSize: isTv ? 12 : 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

StremioTilePresentation stremioTilePresentation(Map<String, dynamic> stream, {required bool isResumable}) {
  final externalUrl = stream['externalUrl']?.toString();
  final isExternal = externalUrl != null && externalUrl.isNotEmpty;
  final isStremioLink = isExternal && externalUrl.startsWith('stremio://');
  final isWebLink =
      isExternal && (externalUrl.startsWith('http://') || externalUrl.startsWith('https://'));

  IconData leadingIcon;
  Color leadingColor;
  if (isStremioLink) {
    final parsed = StremioService.parseMetaLink(externalUrl);
    final action = parsed?['action'];
    if (action == 'detail') {
      leadingIcon = Icons.movie_outlined;
      leadingColor = Colors.amberAccent;
    } else if (action == 'search') {
      leadingIcon = Icons.search_rounded;
      leadingColor = Colors.cyanAccent;
    } else {
      leadingIcon = Icons.explore_outlined;
      leadingColor = Colors.tealAccent;
    }
  } else if (isWebLink) {
    leadingIcon = Icons.language_rounded;
    leadingColor = Colors.lightBlueAccent;
  } else if (isResumable) {
    leadingIcon = Icons.play_circle_filled_rounded;
    leadingColor = ForjaShellColors.textPrimary;
  } else {
    leadingIcon = Icons.extension_rounded;
    leadingColor = Colors.blueAccent;
  }

  return StremioTilePresentation(
    leadingIcon: leadingIcon,
    leadingColor: leadingColor,
    isExternal: isExternal,
  );
}

class StremioTilePresentation {
  const StremioTilePresentation({
    required this.leadingIcon,
    required this.leadingColor,
    required this.isExternal,
  });

  final IconData leadingIcon;
  final Color leadingColor;
  final bool isExternal;
}
