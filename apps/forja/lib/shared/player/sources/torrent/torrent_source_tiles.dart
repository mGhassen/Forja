import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/downloads/download_enqueue.dart';
import 'package:forja/shared/downloads/download_source_match.dart';
import 'package:forja/shared/engine/details/sources_panel_tv.dart';
import 'package:forja/shared/utils/torrent_meta_parser.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
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
    this.onPrepareDownload,
  });

  final TorrentResult result;
  final VoidCallback onPlay;
  final double progress;
  final bool isResumable;
  final bool highlightStart;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final Future<SourceDownloadPrep?> Function()? onPrepareDownload;

  @override
  Widget build(BuildContext context) {
    final meta = TorrentMetaParser.parse(result.name);
    final seedsLabel = result.seedersCount > 0
        ? '${result.seedersCount}'
        : (result.seeders.trim().isEmpty ? null : result.seeders.trim());
    final sizeLabel = TorrentMetaParser.resolveSizeLabel(
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
      onPrepareDownload: onPrepareDownload,
      badges: [
        if (meta.quality != null)
          _SourceBadgeSpec(meta.quality!, tone: _SourceBadgeTone.emphasis),
        if (sizeLabel != null)
          _SourceBadgeSpec(sizeLabel, tone: _SourceBadgeTone.size),
        if (meta.container != null) _SourceBadgeSpec(meta.container!),
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
    final meta = TorrentMetaParser.parse(title);
    final sizeLabel = TorrentMetaParser.resolveSizeLabel(
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
        if (meta.container != null) _SourceBadgeSpec(meta.container!),
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

/// Flat Sources-panel row (left check bar) — movies webstreaming + Forja Sports.
class SourcesPanelChannelTile extends StatelessWidget {
  const SourcesPanelChannelTile({
    super.key,
    required this.title,
    required this.onPlay,
    this.provider,
    this.leading,
    this.footer,
    this.footerLabel,
    this.badges = const [],
    this.tvItemIndex,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onHoverProbe,
    this.probeHealthCache,
    this.viewerCount,
    this.selected = false,
    this.autofocus = false,
  });

  final String title;
  final VoidCallback onPlay;
  final String? provider;
  final Widget? leading;
  final Widget? footer;
  /// Host / embed line — painted by the card so selected can tint green.
  final String? footerLabel;
  final List<String> badges;
  final int? viewerCount;
  final int? tvItemIndex;
  /// Override Sources panel graph (e.g. Live Sports side panel).
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final Future<bool> Function()? onHoverProbe;
  final bool? probeHealthCache;
  /// Playing / current row — brand-green text + Playing status.
  final bool selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return _SourceBadgeCard(
      onTap: onPlay,
      title: title,
      provider: provider,
      leading: leading,
      footer: footer,
      footerLabel: footerLabel,
      tvItemIndex: tvItemIndex,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      onLeftEdge: onLeftEdge,
      onHoverProbe: onHoverProbe,
      probeHealthCache: probeHealthCache,
      viewerCount: viewerCount,
      selected: selected,
      autofocus: autofocus,
      badges: [
        for (final label in badges)
          if (label.trim().isNotEmpty)
            _SourceBadgeSpec(label.trim(), tone: _SourceBadgeTone.emphasis),
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
    this.probeHealthCache,
    this.onPrepareDownload,
    this.downloadChrome = SourceDownloadChrome.none,
    this.downloadProgress = 0,
    this.downloadStatusLabel,
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
  final bool? probeHealthCache;
  final Future<SourceDownloadPrep?> Function()? onPrepareDownload;
  final SourceDownloadChrome downloadChrome;
  final double downloadProgress;
  final String? downloadStatusLabel;

  @override
  Widget build(BuildContext context) {
    final blob = '$title $description ${sizeText ?? ''}';
    final meta = isExternal
        ? const TorrentMetaParser(
            quality: null,
            languageCodes: [],
            audioTags: [],
            techTags: [],
            sourceTags: [],
            videoCodec: null,
            container: null,
          )
        : TorrentMetaParser.parse(blob);
    final sizeLabel = isExternal
        ? null
        : (stream != null
              ? TorrentMetaParser.resolveStreamSizeLabel(stream!)
              : TorrentMetaParser.resolveSizeLabel(
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
      probeHealthCache: isExternal ? null : probeHealthCache,
      onPrepareDownload: isExternal ? null : onPrepareDownload,
      downloadChrome: isExternal ? SourceDownloadChrome.none : downloadChrome,
      downloadProgress: downloadProgress,
      downloadStatusLabel: downloadStatusLabel,
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
              if (meta.container != null) _SourceBadgeSpec(meta.container!),
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
    this.selected = false,
    this.leading,
    this.footer,
    this.footerLabel,
    this.accentBorder,
    this.accentFill,
    this.provider,
    this.seeders,
    this.languageCodes = const [],
    this.magnet,
    this.tvItemIndex,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onHoverProbe,
    this.probeHealthCache,
    this.viewerCount,
    this.autofocus = false,
    this.onPrepareDownload,
    this.downloadChrome = SourceDownloadChrome.none,
    this.downloadProgress = 0,
    this.downloadStatusLabel,
  });

  final VoidCallback onTap;
  final String title;
  final List<_SourceBadgeSpec> badges;
  final double progress;
  final bool isResumable;
  final bool highlightStart;
  /// Playing row in player Source menu — brand-green chrome + Playing.
  final bool selected;
  final bool autofocus;
  final Widget? leading;
  final Widget? footer;
  final String? footerLabel;
  final Color? accentBorder;
  final Color? accentFill;
  final String? provider;
  final String? seeders;
  final List<String> languageCodes;
  final String? magnet;
  final int? tvItemIndex;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final Future<bool> Function()? onHoverProbe;
  final bool? probeHealthCache;
  final int? viewerCount;
  /// Portal-style: Download → probe size → card face becomes confirm + Yes/No.
  final Future<SourceDownloadPrep?> Function()? onPrepareDownload;
  final SourceDownloadChrome downloadChrome;
  final double downloadProgress;
  final String? downloadStatusLabel;

  @override
  State<_SourceBadgeCard> createState() => _SourceBadgeCardState();
}

class _SourceBadgeCardState extends State<_SourceBadgeCard>
    with SingleTickerProviderStateMixin {
  static const _hoverProbeDelay = Duration(milliseconds: 400);
  static const _probeBarWidth = 4.0;

  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;
  AnimationController? _stripeCtrl;
  bool? _probeHealth;
  bool _probeChecking = false;
  bool _probeHoverActive = false;
  int _probeGen = 0;
  Timer? _hoverProbeTimer;

  /// idle · probing · confirm (portal delete / share pattern).
  var _downloadPhase = _DownloadCardPhase.idle;
  SourceDownloadPrep? _downloadPrep;
  int _downloadGen = 0;

  @override
  void dispose() {
    _cancelHoverProbe();
    _stripeCtrl?.dispose();
    _stripeCtrl = null;
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  bool _hoverFor(bool hovered) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: hovered,
        focused: _focused,
        context: context,
      );

  bool get _downloadConfirming =>
      _downloadPhase == _DownloadCardPhase.probing ||
      _downloadPhase == _DownloadCardPhase.confirm;

  void _cancelDownloadConfirm() {
    _downloadGen++;
    setState(() {
      _downloadPhase = _DownloadCardPhase.idle;
      _downloadPrep = null;
    });
  }

  Future<void> _beginDownloadConfirm() async {
    final prepare = widget.onPrepareDownload;
    if (prepare == null) return;
    final gen = ++_downloadGen;
    setState(() {
      _downloadPhase = _DownloadCardPhase.probing;
      _downloadPrep = null;
    });
    final prep = await prepare();
    if (!mounted || gen != _downloadGen) return;
    if (prep == null) {
      setState(() {
        _downloadPhase = _DownloadCardPhase.idle;
        _downloadPrep = null;
      });
      return;
    }
    setState(() {
      _downloadPhase = _DownloadCardPhase.confirm;
      _downloadPrep = prep;
    });
  }

  Future<void> _commitDownload() async {
    final prep = _downloadPrep;
    if (prep == null || !prep.canConfirm) return;
    _cancelDownloadConfirm();
    await prep.commit();
  }

  @override
  void initState() {
    super.initState();
    _probeHealth = widget.probeHealthCache;
    _syncStripeAnim();
  }

  @override
  void didUpdateWidget(covariant _SourceBadgeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cached = widget.probeHealthCache;
    if (cached != null && cached != _probeHealth) {
      _probeHealth = cached;
    }
    if (oldWidget.downloadChrome != widget.downloadChrome) {
      _syncStripeAnim();
    }
  }

  void _syncStripeAnim() {
    final need =
        widget.downloadChrome == SourceDownloadChrome.downloading;
    if (need) {
      _stripeCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat();
      if (!(_stripeCtrl?.isAnimating ?? false)) {
        _stripeCtrl?.repeat();
      }
    } else {
      _stripeCtrl?.stop();
    }
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
      if (_probeHoverActive) {
        setState(() => _probeHoverActive = false);
      }
      return;
    }
    if (widget.onHoverProbe != null && !_probeHoverActive) {
      setState(() => _probeHoverActive = true);
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
      _probeHoverActive = false;
    });
  }

  Color _backgroundColor(bool hovered) {
    final active = _hoverFor(hovered) || _downloadConfirming;
    if (widget.selected) {
      return ForjaShellColors.brandGreen.withValues(alpha: 0.16);
    }
    if (active) return ForjaShellColors.chipSelectedBg;
    if (widget.accentFill != null) return widget.accentFill!;
    if (widget.highlightStart) {
      return ForjaShellColors.chipSelectedBg;
    }
    return Colors.white.withValues(alpha: 0.04);
  }

  Color _borderColor(bool hovered) {
    final active = _hoverFor(hovered) || _downloadConfirming;
    if (widget.selected) {
      return active
          ? ForjaShellColors.brandGreen
          : ForjaShellColors.brandGreen.withValues(alpha: 0.40);
    }
    if (active) return ForjaShellColors.chipSelectedBorder;
    if (widget.accentBorder != null) return widget.accentBorder!;
    if (widget.highlightStart) {
      return ForjaShellColors.chipSelectedBorder;
    }
    return Colors.white.withValues(alpha: 0.07);
  }

  double _borderWidth(bool hovered) {
    if (widget.selected || _hoverFor(hovered) || _downloadConfirming) {
      return 1.5;
    }
    return 1;
  }

  Color _probeLeftBarColor() {
    if (widget.selected) return ForjaShellColors.brandGreen;
    if (widget.onHoverProbe == null) return Colors.transparent;
    if (_probeChecking || (_probeHoverActive && _probeHealth == null)) {
      return Colors.white.withValues(alpha: 0.35);
    }
    return switch (_probeHealth) {
      true => const Color(0xFF22C55E),
      false => const Color(0xFFEF4444),
      null => Colors.transparent,
    };
  }

  Widget _downloadConfirmFace({
    required double titleSize,
    required Color metaColor,
    required double metaFontSize,
  }) {
    final probing = _downloadPhase == _DownloadCardPhase.probing;
    final prep = _downloadPrep;
    final blocked = prep != null && !prep.canConfirm;
    final sizeColor = blocked
        ? const Color(0xFFF87171)
        : ForjaShellColors.brandGreen;
    final sizeText = probing
        ? 'Checking size…'
        : (prep?.sizeLabel ?? 'Size unknown');
    final detail = prep?.detailLine;
    final spaceWarn = prep?.blockReason == 'space'
        ? 'Not enough free space'
        : null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            probing ? 'DOWNLOAD' : 'DOWNLOAD OFFLINE?',
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (probing) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ForjaShellColors.brandGreen,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  sizeText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sizeColor,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: metaColor,
                fontSize: metaFontSize,
              ),
            ),
          ],
          if (spaceWarn != null) ...[
            const SizedBox(height: 4),
            Text(
              spaceWarn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFF87171),
                fontSize: metaFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFace(bool hovered) {
    final metrics = ShellScope.metricsOf(context);
    final padV = metrics.torrentPanelRowPadV;
    final titleSize = metrics.torrentPanelRowTitleFontSize;
    final badgeGap = metrics.usesTvDensity ? 4.0 : 6.0;
    final titleGap = metrics.usesTvDensity ? 5.0 : 8.0;
    final cinematic = ForjaShellColors.cinematic;
    final selected = widget.selected;
    final accentFg = ForjaShellColors.brandGreen;
    final accentMeta = accentFg.withValues(alpha: 0.85);
    final titleColor = selected ? accentFg : cinematic.textPrimary;
    final metaColor = selected ? accentMeta : cinematic.textSecondary;
    final hasProvider =
        widget.provider != null && widget.provider!.trim().isNotEmpty;
    final hasViewers = (widget.viewerCount ?? 0) > 0;
    final titlePrefixBadges = widget.badges
        .where((b) => b.tone == _SourceBadgeTone.emphasis)
        .toList();
    final inlineBadges = widget.badges
        .where((b) => b.tone != _SourceBadgeTone.emphasis)
        .toList();
    final hasSeeders =
        widget.seeders != null && widget.seeders!.trim().isNotEmpty;
    final hasLanguageFlags = widget.languageCodes.isNotEmpty;
    final magnet = widget.magnet;
    final hasMagnet = magnet != null && magnet.isNotEmpty;
    final reveal = _downloadConfirming ||
        (_hoverFor(hovered) &&
            (widget.onPrepareDownload != null || hasMagnet));
    const seedColor = Color(0xFF22C55E);
    final providerLines = hasProvider
        ? _providerLines(widget.provider!)
        : const <String>[];
    final footerLabel = (widget.footerLabel ?? '').trim();
    final hasFooterLabel = footerLabel.isNotEmpty;
    final leftBarColor = _probeLeftBarColor();
    final railIconCount = _downloadConfirming
        ? 2
        : (widget.onPrepareDownload != null ? 1 : 0) + (hasMagnet ? 1 : 0);
    final hit = metrics.usesTvDensity ? 36.0 : 40.0;
    final actionPadH = metrics.usesTvDensity ? 8.0 : 10.0;
    final actionWidth = railIconCount > 0
        ? (hit * railIconCount) + (actionPadH * 2)
        : 0.0;
    final railAnim = const Duration(milliseconds: 180);
    final iconSize = metrics.usesTvDensity ? 18.0 : 20.0;
    final prep = _downloadPrep;
    final canYes = prep != null && prep.canConfirm;

    Widget mainColumn = _downloadConfirming
        ? _downloadConfirmFace(
            titleSize: titleSize,
            metaColor: metaColor,
            metaFontSize: metrics.torrentPanelMetaFontSize,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titlePrefixBadges.isNotEmpty) ...[
                    Wrap(
                      spacing: badgeGap,
                      runSpacing: badgeGap,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final badge in titlePrefixBadges)
                          _SourceMetaBadge(badge: badge),
                      ],
                    ),
                    SizedBox(width: titleGap),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: titleSize,
                        height: 1.25,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasLanguageFlags || inlineBadges.isNotEmpty) ...[
                SizedBox(height: titleGap),
                Wrap(
                  spacing: badgeGap,
                  runSpacing: badgeGap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hasLanguageFlags)
                      _LanguageFlagBadges(
                        codes: widget.languageCodes,
                      ),
                    for (final badge in inlineBadges)
                      _SourceMetaBadge(badge: badge),
                  ],
                ),
              ],
              if (hasFooterLabel) ...[
                const SizedBox(height: 4),
                Text(
                  footerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: metaColor,
                    fontSize: metrics.torrentPanelMetaFontSize,
                  ),
                ),
              ] else if (widget.footer != null) ...[
                const SizedBox(height: 4),
                widget.footer!,
              ],
              if (selected) ...[
                const SizedBox(height: 2),
                Text(
                  'Playing',
                  style: TextStyle(
                    color: accentFg,
                    fontSize: metrics.torrentPanelMetaFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );

    Widget main = Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.torrentPanelRowPadH,
        padV,
        metrics.torrentPanelRowPadH,
        padV,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.leading != null && !_downloadConfirming) ...[
            widget.leading!,
            SizedBox(width: titleGap),
          ],
          Expanded(child: mainColumn),
          if (!_downloadConfirming &&
              (selected ||
                  hasProvider ||
                  hasViewers ||
                  hasSeeders ||
                  widget.downloadChrome != SourceDownloadChrome.none)) ...[
            SizedBox(width: titleGap),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (selected)
                    Icon(
                      Icons.check_rounded,
                      color: ForjaShellColors.brandGreen,
                      size: metrics.torrentPanelLeadingIconSize,
                    ),
                  if (hasProvider)
                    ...providerLines.asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(
                          top: entry.key == 0 && !selected ? 0 : 2,
                        ),
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: metaColor,
                            fontSize: metrics.torrentPanelMetaFontSize,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      );
                    }),
                  if (widget.downloadChrome ==
                      SourceDownloadChrome.downloading) ...[
                    if (hasProvider || selected) const SizedBox(height: 2),
                    Text(
                      (widget.downloadStatusLabel ?? '').trim().isEmpty
                          ? '${(widget.downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                          : widget.downloadStatusLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: ForjaShellColors.brandGreen,
                        fontSize: metrics.torrentPanelMetaFontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                  if (widget.downloadChrome ==
                      SourceDownloadChrome.offline) ...[
                    if (hasProvider || selected) const SizedBox(height: 2),
                    Text(
                      'Offline',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: ForjaShellColors.brandGreen,
                        fontSize: metrics.torrentPanelMetaFontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                  if (hasViewers) ...[
                    if (hasProvider || selected) const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: metrics.torrentPanelMetaFontSize,
                          color: metaColor.withValues(
                            alpha: selected ? 0.85 : 0.75,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.viewerCount}',
                          style: TextStyle(
                            color: metaColor,
                            fontSize: metrics.torrentPanelMetaFontSize,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hasSeeders) ...[
                    if (hasProvider) const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: metrics.torrentPanelMetaFontSize,
                          color: seedColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.seeders!,
                          style: TextStyle(
                            color: seedColor,
                            fontSize: metrics.torrentPanelMetaFontSize,
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
    );

    Widget actionRail;
    if (_downloadConfirming) {
      actionRail = Padding(
        padding: EdgeInsets.symmetric(horizontal: actionPadH),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SourceRailIcon(
              icon: Icons.check_rounded,
              idle: canYes ? Colors.white60 : Colors.white24,
              hit: hit,
              iconSize: iconSize,
              onTap: canYes ? () => unawaited(_commitDownload()) : null,
            ),
            _SourceRailIcon(
              icon: Icons.close_rounded,
              idle: Colors.white60,
              hit: hit,
              iconSize: iconSize,
              onTap: _cancelDownloadConfirm,
            ),
          ],
        ),
      );
    } else {
      actionRail = Padding(
        padding: EdgeInsets.symmetric(horizontal: actionPadH),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.onPrepareDownload != null)
              _SourceRailIcon(
                tooltip: 'Download',
                icon: Icons.download_rounded,
                idle: Colors.white60,
                hit: hit,
                iconSize: iconSize,
                onTap: () => unawaited(_beginDownloadConfirm()),
              ),
            if (hasMagnet)
              _SourceRailIcon(
                tooltip: 'Copy magnet',
                icon: Icons.content_copy_rounded,
                idle: Colors.white60,
                hit: hit,
                iconSize: iconSize,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: magnet));
                  ForjaToast.success(
                    'Magnet copied',
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
          ],
        ),
      );
    }

    // Stack + Positioned probe bar — not Row(stretch). ListView children get
    // unbounded max height; stretch forces infinite height and blows the panel
    // (Live Sports Providers). Avoid IntrinsicHeight (issue 352 lag).
    //
    // Push-in rail uses Align.widthFactor (not OverflowBox) — OverflowBox got
    // infinite max height in this ListView and threw on hover, hiding Download.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _backgroundColor(hovered),
        border: Border.all(
          color: _borderColor(hovered),
          width: _borderWidth(hovered),
        ),
      ),
      // Portal-style: probe | main | push-in action rail (RFC-117).
      child: ClipRect(
        child: Stack(
          children: [
            if (widget.downloadChrome == SourceDownloadChrome.offline)
              const Positioned.fill(
                child: CustomPaint(painter: _SourceOfflineStripePainter()),
              ),
            if (widget.downloadChrome == SourceDownloadChrome.downloading)
              Positioned.fill(
                child: _SourceDownloadingChrome(
                  progress: widget.downloadProgress,
                  controller: _stripeCtrl,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: _probeBarWidth),
                Expanded(child: main),
                if (railIconCount > 0)
                  ClipRect(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: reveal ? 1.0 : 0.0),
                      duration: railAnim,
                      curve: Curves.easeOutCubic,
                      builder: (context, factor, child) {
                        return Align(
                          alignment: Alignment.centerRight,
                          widthFactor: factor.clamp(0.0, 1.0),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        width: actionWidth,
                        child: Align(
                          alignment: Alignment.center,
                          child: actionRail,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _probeBarWidth,
              child: ColoredBox(color: leftBarColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvItemIndex != null &&
        (widget.tvTabId != null || SourcesPanelTv.isTv(context));
    final tabId = widget.tvTabId ?? SourcesPanelTv.tabId;
    final rowId = widget.tvRowId ?? SourcesPanelTv.listRowId;
    return shellFocusableTap(
      context: context,
      onTap: () {
        if (_downloadConfirming) {
          _cancelDownloadConfirm();
          return;
        }
        widget.onTap();
      },
      borderRadius: 0,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      suppressInkHover: true,
      autoFocus: widget.autofocus,
      listIndex: tv ? widget.tvItemIndex : null,
      tvTabId: tv ? tabId : null,
      tvRowId: tv ? rowId : null,
      tvItemIndex: tv ? widget.tvItemIndex : null,
      ensureVisibleMode: ShellPaintEnsureVisible.off,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
      onLeftEdge: widget.onLeftEdge,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        _syncHoverProbe(focused || _hoveredN.value);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          _setHovered(true);
          _syncHoverProbe(true);
        },
        onExit: (_) {
          if (_downloadConfirming) return;
          _setHovered(false);
          _syncHoverProbe(false);
        },
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) => _buildFace(_hoveredN.value),
        ),
      ),
    );
  }
}

enum _DownloadCardPhase { idle, probing, confirm }

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
    final metrics = ShellScope.metricsOf(context);
    final tv = metrics.usesTvDensity;
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
      padding: EdgeInsets.symmetric(
        horizontal: tv
            ? ShellTokens.torrentPanelRowBadgePadHTv
            : ShellTokens.torrentPanelRowBadgePadHDesktop,
        vertical: tv
            ? ShellTokens.torrentPanelRowBadgePadVTv
            : ShellTokens.torrentPanelRowBadgePadVDesktop,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(
          tv
              ? ShellTokens.torrentPanelRowBadgeRadiusTv
              : ShellTokens.torrentPanelRowBadgeRadiusDesktop,
        ),
        border: Border.all(color: border),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          color: fg,
          fontSize: metrics.torrentPanelChipFontSize,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Portal-style rail icon — plain glyph, brand-green on hover (not a Material button).
class _SourceRailIcon extends StatefulWidget {
  const _SourceRailIcon({
    this.tooltip,
    required this.icon,
    required this.idle,
    required this.hit,
    required this.iconSize,
    this.onTap,
  });

  final String? tooltip;
  final IconData icon;
  final Color idle;
  final double hit;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  State<_SourceRailIcon> createState() => _SourceRailIconState();
}

class _SourceRailIconState extends State<_SourceRailIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = !enabled
        ? widget.idle
        : (_hovered ? ForjaShellColors.brandGreen : widget.idle);
    Widget icon = SizedBox(
      width: widget.hit,
      height: widget.hit,
      child: Center(
        child: Icon(
          widget.icon,
          size: widget.iconSize,
          color: color,
        ),
      ),
    );
    final tip = widget.tooltip?.trim();
    if (tip != null && tip.isNotEmpty) {
      icon = Tooltip(message: tip, child: icon);
    }
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: icon,
      ),
    );
  }
}

class _SourceDownloadingChrome extends StatelessWidget {
  const _SourceDownloadingChrome({
    required this.progress,
    required this.controller,
  });

  final double progress;
  final AnimationController? controller;

  @override
  Widget build(BuildContext context) {
    final fill = progress.clamp(0.0, 1.0);
    final widthFactor = fill <= 0 ? 0.08 : fill;
    final ctrl = controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            heightFactor: 1,
            child: ColoredBox(
              color: ForjaShellColors.brandGreen.withValues(alpha: 0.14),
            ),
          ),
        ),
        if (ctrl != null)
          AnimatedBuilder(
            animation: ctrl,
            builder: (context, _) => CustomPaint(
              painter: _SourceMovingStripePainter(progress: ctrl.value),
            ),
          ),
      ],
    );
  }
}

/// Static diagonal stripes for a completed offline source row.
class _SourceOfflineStripePainter extends CustomPainter {
  const _SourceOfflineStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ForjaShellColors.brandGreen.withValues(alpha: 0.12)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    const spacing = 14.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SourceOfflineStripePainter oldDelegate) => false;
}

/// Animated diagonal stripes while a source is downloading.
class _SourceMovingStripePainter extends CustomPainter {
  const _SourceMovingStripePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ForjaShellColors.brandGreen.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    const spacing = 14.0;
    final shift = progress * spacing;
    for (double x = -size.height - spacing;
        x < size.width + size.height + spacing;
        x += spacing) {
      final ox = x + shift;
      canvas.drawLine(
        Offset(ox, size.height),
        Offset(ox + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SourceMovingStripePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
