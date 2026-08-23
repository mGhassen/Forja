import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

class TorrentSourceTile extends StatelessWidget {
  const TorrentSourceTile({
    super.key,
    required this.result,
    required this.onPlay,
    this.progress = 0,
    this.isResumable = false,
    this.highlightStart = false,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
  });

  final TorrentResult result;
  final VoidCallback onPlay;
  final double progress;
  final bool isResumable;
  final bool highlightStart;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    final meta = TorrentReleaseMetadata.parse(result.name);
    final seedsLabel = result.seedersCount > 0
        ? '${result.seedersCount}'
        : (result.seeders.trim().isEmpty ? null : result.seeders.trim());
    final sizeLabel = TorrentReleaseMetadata.resolveSizeLabel(
      sizeText: result.size,
      fallbackText: result.name,
    );
    final source = result.source.trim();
    final provider =
        source.isNotEmpty &&
            source.toLowerCase() != 'unknown' &&
            !result.name.toLowerCase().contains(source.toLowerCase())
        ? source
        : null;
    final magnet = result.magnet.trim();

    return _SourceBadgeCard(
      onTap: onPlay,
      progress: progress,
      isResumable: isResumable,
      highlightStart: highlightStart,
      title: result.name,
      provider: provider,
      seeders: seedsLabel,
      languageCodes: meta.languageCodes,
      magnet: magnet.isEmpty ? null : magnet,
      tvItemIndex: tvItemIndex,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      badges: [
        if (meta.quality != null)
          _SourceBadgeSpec(meta.quality!, tone: _SourceBadgeTone.emphasis),
        if (sizeLabel != null)
          _SourceBadgeSpec(sizeLabel, tone: _SourceBadgeTone.size),
        if (meta.videoCodec != null) _SourceBadgeSpec(meta.videoCodec!),
        ...meta.audioTags.take(1).map(_SourceBadgeSpec.new),
        ...meta.techTags.take(2).map(_SourceBadgeSpec.new),
        ...meta.sourceTags.take(1).map(_SourceBadgeSpec.new),
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
    this.progress = 0,
    this.isResumable = false,
    this.highlightStart = false,
    this.provider,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onHoverProbe,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onPlay;
  final double progress;
  final bool isResumable;
  final bool highlightStart;
  final String? provider;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final Future<bool> Function()? onHoverProbe;

  @override
  Widget build(BuildContext context) {
    final meta = TorrentReleaseMetadata.parse(title);
    final sizeLabel = TorrentReleaseMetadata.resolveSizeLabel(
      sizeText: subtitle,
      fallbackText: title,
    );

    return _SourceBadgeCard(
      onTap: onPlay,
      progress: progress,
      isResumable: isResumable,
      highlightStart: highlightStart,
      title: title,
      provider: provider,
      tvItemIndex: tvItemIndex,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      onHoverProbe: onHoverProbe,
      languageCodes: meta.languageCodes,
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

/// Multi-file torrent file row - same card as Sources / [WebstreamingSourceTile].
class TorrentFileSourceTile extends StatelessWidget {
  const TorrentFileSourceTile({
    super.key,
    required this.fileName,
    required this.sizeBytes,
    required this.onPlay,
    this.isCurrent = false,
    this.isSwitching = false,
    this.enabled = true,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
  });

  final String fileName;
  final int sizeBytes;
  final VoidCallback onPlay;
  final bool isCurrent;
  final bool isSwitching;
  final bool enabled;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final tile = WebstreamingSourceTile(
      title: fileName,
      subtitle: _formatSize(sizeBytes),
      highlightStart: isCurrent,
      provider: isCurrent ? 'Playing' : null,
      onPlay: onPlay,
      tvItemIndex: tvItemIndex,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
    );

    if (!enabled && !isSwitching) {
      return Opacity(opacity: 0.4, child: IgnorePointer(child: tile));
    }

    if (!isSwitching) return tile;

    return Stack(
      children: [
        Opacity(opacity: 0.55, child: IgnorePointer(child: tile)),
        const Positioned.fill(
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
        ),
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
    this.stream,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onHoverProbe,
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
  final Map<String, dynamic>? stream;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final Future<bool> Function()? onHoverProbe;

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
        : (stream != null
              ? TorrentReleaseMetadata.resolveStreamSizeLabel(stream!)
              : TorrentReleaseMetadata.resolveSizeLabel(
                  sizeText: sizeText,
                  fallbackText: blob,
                ));
    final seedsRaw = seeders?.trim();
    final seedsCount =
        int.tryParse((seedsRaw ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final seedsLabel = seedsCount > 0 ? '$seedsCount' : null;
    final provider = addonName != null && showAddonName ? addonName : null;

    return _SourceBadgeCard(
      onTap: onTap,
      progress: progress,
      isResumable: isResumable && !isExternal,
      highlightStart: highlightStart && !isExternal,
      leading: isExternal
          ? Icon(
              leadingIcon,
              color: leadingColor,
              size: ShellScope.metricsOf(context).torrentPanelLeadingIconSize,
            )
          : null,
      accentBorder: isExternal ? leadingColor.withValues(alpha: 0.25) : null,
      accentFill: isExternal ? leadingColor.withValues(alpha: 0.06) : null,
      title: title,
      provider: provider,
      seeders: isExternal ? null : seedsLabel,
      languageCodes: isExternal ? const [] : meta.languageCodes,
      tvItemIndex: tvItemIndex,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      onHoverProbe: isExternal ? null : onHoverProbe,
      badges: isExternal
          ? [
              if (description.trim().isNotEmpty)
                _SourceBadgeSpec(description.trim()),
            ]
          : [
              if (meta.quality != null)
                _SourceBadgeSpec(
                  meta.quality!,
                  tone: _SourceBadgeTone.emphasis,
                ),
              if (sizeLabel != null)
                _SourceBadgeSpec(sizeLabel, tone: _SourceBadgeTone.size),
              if (meta.videoCodec != null) _SourceBadgeSpec(meta.videoCodec!),
              ...meta.audioTags.take(1).map(_SourceBadgeSpec.new),
              ...meta.techTags.take(2).map(_SourceBadgeSpec.new),
              ...meta.sourceTags.take(1).map(_SourceBadgeSpec.new),
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
  final isWebLink =
      isExternal &&
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

enum _SourceBadgeTone { muted, emphasis, size, accent }

class _SourceBadgeSpec {
  const _SourceBadgeSpec(this.label, {this.tone = _SourceBadgeTone.muted});

  final String label;
  final _SourceBadgeTone tone;
}

class _SourceBadgeCard extends StatefulWidget {
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
    this.provider,
    this.seeders,
    this.languageCodes = const [],
    this.magnet,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onHoverProbe,
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
  final String? provider;
  final String? seeders;
  final List<String> languageCodes;
  final String? magnet;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final Future<bool> Function()? onHoverProbe;

  @override
  State<_SourceBadgeCard> createState() => _SourceBadgeCardState();
}

class _SourceBadgeCardState extends State<_SourceBadgeCard> {
  static const _hoverProbeDelay = Duration(milliseconds: 500);

  bool _hovered = false;
  bool _focused = false;
  bool? _probeHealth;
  bool _probeChecking = false;
  int _probeGen = 0;
  Timer? _hoverProbeTimer;

  bool get _hover => _hovered || _focused;

  @override
  void dispose() {
    _cancelHoverProbe();
    super.dispose();
  }

  bool _shouldScheduleHoverProbe() {
    if (widget.onHoverProbe == null) return false;
    if (_probeChecking) return false;
    if (_probeHealth == true) return false;
    return true;
  }

  void _syncHoverProbe(bool active) {
    if (!active) {
      _cancelHoverProbe();
      return;
    }
    if (!_shouldScheduleHoverProbe()) return;
    _cancelHoverProbe();
    _hoverProbeTimer = Timer(_hoverProbeDelay, () {
      _hoverProbeTimer = null;
      if (!mounted || !_shouldScheduleHoverProbe()) return;
      unawaited(_runHoverProbe());
    });
  }

  void _cancelHoverProbe() {
    _hoverProbeTimer?.cancel();
    _hoverProbeTimer = null;
  }

  Future<void> _runHoverProbe() async {
    final probe = widget.onHoverProbe;
    if (probe == null) return;
    final gen = ++_probeGen;
    setState(() => _probeChecking = true);
    final ok = await probe();
    if (!mounted || gen != _probeGen) return;
    setState(() {
      _probeChecking = false;
      _probeHealth = ok;
    });
  }

  Color _backgroundColor() {
    if (_probeHealth == false) {
      return const Color(0xFFEF4444).withValues(alpha: _hover ? 0.11 : 0.08);
    }
    if (_hover) return ForjaShellColors.chipSelectedBg;
    if (widget.accentFill != null) return widget.accentFill!;
    if (widget.isResumable || widget.highlightStart) {
      return ForjaShellColors.chipSelectedBg;
    }
    return Colors.white.withValues(alpha: 0.04);
  }

  Color _borderColor() {
    if (widget.onHoverProbe != null) {
      if (_probeChecking) {
        return Colors.white.withValues(alpha: _hover ? 0.28 : 0.18);
      }
      if (_probeHealth == true) {
        return const Color(0xFF22C55E).withValues(alpha: _hover ? 0.62 : 0.45);
      }
      if (_probeHealth == false) {
        return const Color(0xFFEF4444).withValues(alpha: _hover ? 0.72 : 0.55);
      }
    }
    if (_hover) return ForjaShellColors.chipSelectedBorder;
    if (widget.accentBorder != null) return widget.accentBorder!;
    if (widget.isResumable || widget.highlightStart) {
      return ForjaShellColors.chipSelectedBorder;
    }
    return Colors.white.withValues(alpha: 0.07);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    const padV = 10.0;
    const titleSize = 13.0;
    final cinematic = ForjaShellColors.cinematic;
    final hasProvider =
        widget.provider != null && widget.provider!.trim().isNotEmpty;
    final hasSeeders =
        widget.seeders != null && widget.seeders!.trim().isNotEmpty;
    final hasLanguageFlags = widget.languageCodes.isNotEmpty;
    final magnet = widget.magnet;
    final showCopyMagnet = magnet != null && magnet.isNotEmpty && _hovered;
    const seedColor = Color(0xFF22C55E);

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor()),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, padV, 12, padV),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isResumable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            'RESUME',
                            style: TextStyle(
                              color: cinematic.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cinematic.textPrimary,
                                fontSize: titleSize,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (showCopyMagnet) ...[
                            const SizedBox(width: 4),
                            ForjaPlainIcon(
                              icon: Icons.content_copy_rounded,
                              tooltip: 'Copy magnet',
                              size: 15,
                              hitSize: 24,
                              color: cinematic.textSecondary,
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: magnet),
                                );
                                ForjaToast.success(
                                  'Magnet copied',
                                  duration: const Duration(seconds: 2),
                                );
                              },
                            ),
                          ],
                          if (hasProvider || hasSeeders) ...[
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (hasProvider)
                                    ..._providerLines(widget.provider!).map(
                                      (line) => Text(
                                        line,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: cinematic.textSecondary,
                                          fontSize:
                                              metrics.torrentPanelMetaFontSize,
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  if (hasSeeders) ...[
                                    if (hasProvider) const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_upward_rounded,
                                          size:
                                              metrics.torrentPanelMetaFontSize,
                                          color: seedColor,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          widget.seeders!,
                                          style: TextStyle(
                                            color: seedColor,
                                            fontSize: metrics
                                                .torrentPanelMetaFontSize,
                                            fontWeight: FontWeight.w600,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hasLanguageFlags || widget.badges.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (hasLanguageFlags)
                              _LanguageFlagBadges(codes: widget.languageCodes),
                            for (final badge in widget.badges)
                              _SourceMetaBadge(badge: badge),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.isResumable && widget.progress > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: Colors.transparent,
                  color: ForjaShellColors.progressFill,
                  minHeight: 2.5,
                ),
              ),
            ),
          if (_probeChecking)
            const Positioned(
              top: 8,
              right: 8,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
        ],
      ),
    );

    Widget card = face;
    if (widget.onHoverProbe != null) {
      card = MouseRegion(
        onEnter: (_) {
          setState(() => _hovered = true);
          _syncHoverProbe(true);
        },
        onExit: (_) {
          setState(() => _hovered = false);
          _syncHoverProbe(false);
        },
        child: card,
      );
    }

    final tv = widget.tvItemIndex != null && SourcesPanelTv.isTv(context);
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 10,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      suppressInkHover: true,
      listIndex: tv ? widget.tvItemIndex : null,
      tvTabId: tv ? SourcesPanelTv.tabId : null,
      tvRowId: tv ? SourcesPanelTv.listRowId : null,
      tvItemIndex: tv ? widget.tvItemIndex : null,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: widget.onHoverProbe == null
          ? (focused) => setState(() => _focused = focused)
          : (focused) {
              setState(() => _focused = focused);
              _syncHoverProbe(focused || _hovered);
            },
      child: card,
    );
  }
}

/// Split `Plugin · Stream` (engine/Nuvio `_addonName`) into server then stream.
List<String> _providerLines(String provider) {
  final raw = provider.trim();
  if (raw.isEmpty) return const [];
  final parts = raw
      .split(RegExp(r'\s*[·•]\s*'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length < 2) return [raw];
  return [parts.first, parts.sublist(1).join(' · ')];
}

class _LanguageFlagBadges extends StatelessWidget {
  const _LanguageFlagBadges({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const SizedBox.shrink();
    final metrics = ShellScope.metricsOf(context);

    if (StreamProviderDisplay.supportsFlagEmoji) {
      final flags = StreamProviderDisplay.flagsDisplayForCodes(codes);
      if (flags.isEmpty) return const SizedBox.shrink();
      return Text(
        flags,
        style: TextStyle(
          fontSize: metrics.torrentPanelChipFontSize,
          height: 1.1,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final code in codes)
          if (StreamProviderDisplay.flagDisplayForCountry(code).isNotEmpty)
            _SourceMetaBadge(
              badge: _SourceBadgeSpec(
                StreamProviderDisplay.flagDisplayForCountry(code),
              ),
            ),
      ],
    );
  }
}

class _SourceMetaBadge extends StatelessWidget {
  const _SourceMetaBadge({required this.badge});

  final _SourceBadgeSpec badge;

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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
