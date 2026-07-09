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
    final meta = TorrentReleaseMetadata.parse(result.name);
    final seeds = result.seedersCount > 0
        ? '${result.seedersCount}'
        : (result.seeders.trim().isEmpty ? null : result.seeders.trim());
    final hasSeeds = result.seedersCount > 0 ||
        (int.tryParse(result.seeders.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) >
            0;
    final sizeLabel = TorrentReleaseMetadata.resolveSizeLabel(
      sizeText: result.size,
      fallbackText: result.name,
    );
    final source = result.source.trim();

    return _SourceBadgeCard(
      onTap: onPlay,
      progress: progress,
      isResumable: isResumable,
      highlightStart: highlightStart,
      title: result.name,
      badges: [
        if (meta.quality != null)
          _SourceBadgeSpec(meta.quality!, tone: _SourceBadgeTone.emphasis),
        if (sizeLabel != null)
          _SourceBadgeSpec(sizeLabel, tone: _SourceBadgeTone.size),
        if (seeds != null)
          _SourceBadgeSpec(
            '$seeds seeds',
            tone: hasSeeds ? _SourceBadgeTone.seeds : _SourceBadgeTone.muted,
          ),
        if (meta.videoCodec != null) _SourceBadgeSpec(meta.videoCodec!),
        ...meta.audioTags.take(1).map(_SourceBadgeSpec.new),
        ...meta.techTags.take(2).map(_SourceBadgeSpec.new),
        ...meta.sourceTags.take(1).map(_SourceBadgeSpec.new),
        if (meta.flags.trim().isNotEmpty)
          _SourceBadgeSpec(meta.flags.trim()),
        if (source.isNotEmpty &&
            source.toLowerCase() != 'unknown' &&
            !result.name.toLowerCase().contains(source.toLowerCase()))
          _SourceBadgeSpec(source, tone: _SourceBadgeTone.accent),
      ],
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
    final meta = TorrentReleaseMetadata.parse(title);
    final sizeLabel = TorrentReleaseMetadata.resolveSizeLabel(
      sizeText: subtitle,
      fallbackText: title,
    );

    return _SourceBadgeCard(
      onTap: onPlay,
      title: title,
      badges: [
        if (meta.quality != null)
          _SourceBadgeSpec(meta.quality!, tone: _SourceBadgeTone.emphasis),
        if (sizeLabel != null)
          _SourceBadgeSpec(sizeLabel, tone: _SourceBadgeTone.size),
        if (meta.videoCodec != null) _SourceBadgeSpec(meta.videoCodec!),
        ...meta.techTags.take(2).map(_SourceBadgeSpec.new),
        if (subtitle != null &&
            subtitle!.trim().isNotEmpty &&
            sizeLabel == null)
          _SourceBadgeSpec(subtitle!.trim()),
      ],
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
    this.sizeText,
    this.seeders,
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
  final String? sizeText;
  final String? seeders;

  @override
  Widget build(BuildContext context) {
    final blob = '$title $description ${sizeText ?? ''}';
    final meta = isExternal
        ? const TorrentReleaseMetadata(
            quality: null,
            languageCodes: [],
            audioTags: [],
            techTags: [],
            sourceTags: [],
          )
        : TorrentReleaseMetadata.parse(blob);
    final sizeLabel = isExternal
        ? null
        : TorrentReleaseMetadata.resolveSizeLabel(
            sizeText: sizeText,
            fallbackText: blob,
          );
    final seedsRaw = seeders?.trim();
    final seedsCount =
        int.tryParse((seedsRaw ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    return _SourceBadgeCard(
      onTap: onTap,
      progress: progress,
      isResumable: isResumable && !isExternal,
      highlightStart: highlightStart && !isExternal,
      leading: isExternal
          ? Icon(leadingIcon, color: leadingColor, size: ShellTokens.isTvLayout(context) ? 26 : 22)
          : null,
      accentBorder: isExternal ? leadingColor.withValues(alpha: 0.25) : null,
      accentFill: isExternal ? leadingColor.withValues(alpha: 0.06) : null,
      eyebrow: addonName != null && showAddonName ? addonName : null,
      eyebrowColor: leadingColor.withValues(alpha: 0.75),
      title: title,
      badges: isExternal
          ? [
              if (description.trim().isNotEmpty)
                _SourceBadgeSpec(description.trim()),
            ]
          : [
              if (meta.quality != null)
                _SourceBadgeSpec(meta.quality!, tone: _SourceBadgeTone.emphasis),
              if (sizeLabel != null)
                _SourceBadgeSpec(sizeLabel, tone: _SourceBadgeTone.size),
              if (seedsCount > 0)
                _SourceBadgeSpec(
                  '$seedsCount seeds',
                  tone: _SourceBadgeTone.seeds,
                ),
              if (meta.videoCodec != null) _SourceBadgeSpec(meta.videoCodec!),
              ...meta.audioTags.take(1).map(_SourceBadgeSpec.new),
              ...meta.techTags.take(2).map(_SourceBadgeSpec.new),
              ...meta.sourceTags.take(1).map(_SourceBadgeSpec.new),
              if (meta.flags.trim().isNotEmpty)
                _SourceBadgeSpec(meta.flags.trim()),
            ],
    );
  }
}

StremioTilePresentation stremioTilePresentation(
  Map<String, dynamic> stream, {
  required bool isResumable,
}) {
  final externalUrl = stream['externalUrl']?.toString();
  final isExternal = externalUrl != null && externalUrl.isNotEmpty;
  final isStremioLink = isExternal && externalUrl.startsWith('stremio://');
  final isWebLink = isExternal &&
      (externalUrl.startsWith('http://') || externalUrl.startsWith('https://'));

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

enum _SourceBadgeTone { muted, emphasis, size, seeds, accent }

class _SourceBadgeSpec {
  const _SourceBadgeSpec(this.label, {this.tone = _SourceBadgeTone.muted});

  final String label;
  final _SourceBadgeTone tone;
}

class _SourceBadgeCard extends StatelessWidget {
  const _SourceBadgeCard({
    required this.onTap,
    required this.title,
    required this.badges,
    this.progress = 0,
    this.isResumable = false,
    this.highlightStart = false,
    this.leading,
    this.accentBorder,
    this.accentFill,
    this.eyebrow,
    this.eyebrowColor,
  });

  final VoidCallback onTap;
  final String title;
  final List<_SourceBadgeSpec> badges;
  final double progress;
  final bool isResumable;
  final bool highlightStart;
  final Widget? leading;
  final Color? accentBorder;
  final Color? accentFill;
  final String? eyebrow;
  final Color? eyebrowColor;

  @override
  Widget build(BuildContext context) {
    final isTv = ShellTokens.isTvLayout(context);
    final padV = isTv ? 14.0 : 10.0;
    final titleSize = isTv ? 15.0 : 13.0;

    return FocusableControl(
      onTap: onTap,
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: accentFill ??
              ((isResumable || highlightStart)
                  ? ForjaShellColors.chipSelectedBg
                  : Colors.white.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accentBorder ??
                (isResumable
                    ? ForjaShellColors.chipSelectedBorder
                    : Colors.white.withValues(alpha: 0.07)),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, padV, 12, padV),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 10),
                  ],
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
                        if (eyebrow != null && eyebrow!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              eyebrow!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: eyebrowColor ??
                                    ForjaShellColors.cinematic.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          title,
                          maxLines: isTv ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textPrimary,
                            fontSize: titleSize,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final badge in badges)
                                _SourceMetaBadge(badge: badge, isTv: isTv),
                            ],
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
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
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

class _SourceMetaBadge extends StatelessWidget {
  const _SourceMetaBadge({required this.badge, required this.isTv});

  final _SourceBadgeSpec badge;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    late final Color fg;
    late final Color bg;
    late final Color border;

    switch (badge.tone) {
      case _SourceBadgeTone.emphasis:
        fg = cinematic.textPrimary;
        bg = Colors.white.withValues(alpha: 0.14);
        border = Colors.white.withValues(alpha: 0.22);
      case _SourceBadgeTone.size:
        fg = cinematic.textPrimary;
        bg = Colors.white.withValues(alpha: 0.10);
        border = Colors.white.withValues(alpha: 0.18);
      case _SourceBadgeTone.seeds:
        fg = const Color(0xFF22C55E);
        bg = const Color(0xFF22C55E).withValues(alpha: 0.12);
        border = const Color(0xFF22C55E).withValues(alpha: 0.28);
      case _SourceBadgeTone.accent:
        fg = const Color(0xFF60A5FA);
        bg = const Color(0xFF60A5FA).withValues(alpha: 0.10);
        border = const Color(0xFF60A5FA).withValues(alpha: 0.24);
      case _SourceBadgeTone.muted:
        fg = cinematic.textSecondary;
        bg = Colors.white.withValues(alpha: 0.06);
        border = Colors.white.withValues(alpha: 0.10);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTv ? 8 : 7,
        vertical: isTv ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          color: fg,
          fontSize: isTv ? 12 : 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
