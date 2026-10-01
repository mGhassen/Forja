import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:rust/rust.dart';

/// Readable torrent resolve status for [LoadingOverlay] — headline + stat tiles.
class TorrentLoadingStatusPanel extends StatelessWidget {
  const TorrentLoadingStatusPanel({super.key, required this.status});

  final TorrentLoadingStatus status;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final headlineSize = tv
        ? ShellTokens.streamLoadingHeadlineFontSizeTv
        : ShellTokens.streamLoadingHeadlineFontSize;
    final hintSize = tv
        ? ShellTokens.streamLoadingHintFontSizeTv
        : ShellTokens.streamLoadingHintFontSize;
    final hintGap = tv
        ? ShellTokens.streamLoadingHintGapTv
        : ShellTokens.streamLoadingHintGap;
    final hintPad = tv
        ? ShellTokens.streamLoadingHintPadHTv
        : ShellTokens.streamLoadingHintPadH;
    final statsGap = tv
        ? ShellTokens.streamLoadingProgressGapTv
        : ShellTokens.streamLoadingProgressGap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status.headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: headlineSize,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0.15,
            fontFamily: 'Poppins',
          ),
        ),
        if (status.hint != null) ...[
          SizedBox(height: hintGap),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hintPad),
            child: Text(
              status.hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: hintSize,
                fontWeight: FontWeight.w500,
                height: 1.4,
                letterSpacing: 0.1,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
        if (status.hasStats) ...[
          SizedBox(height: statsGap),
          _StatsCard(status: status),
        ],
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.status});

  final TorrentLoadingStatus status;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final maxW = tv
        ? ShellTokens.streamLoadingStatsMaxWidthTv
        : ShellTokens.streamLoadingStatsMaxWidth;
    final radius = tv
        ? ShellTokens.streamLoadingStatsRadiusTv
        : ShellTokens.streamLoadingStatsRadius;
    final padH = tv
        ? ShellTokens.streamLoadingStatsPadHTv
        : ShellTokens.streamLoadingStatsPadH;
    final padV = tv
        ? ShellTokens.streamLoadingStatsPadVTv
        : ShellTokens.streamLoadingStatsPadV;

    final peers = status.activePeers;
    final seen = status.totalPeers;
    final peerValue = peers != null ? '$peers' : '—';
    final peerLabel = seen != null && seen > 0
        ? peers != null && peers > 0 && seen > peers
            ? 'of $seen peers'
            : seen > 0 && (peers ?? 0) == 0
                ? '$seen seen'
                : 'peers'
        : 'peers';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.people_outline_rounded,
                  value: peerValue,
                  label: peerLabel,
                ),
              ),
              _divider(context),
              Expanded(
                child: _StatTile(
                  icon: Icons.download_rounded,
                  value: status.speedLabel ?? '—',
                  label: 'Download',
                  accent: status.speedLabel != null,
                ),
              ),
              _divider(context),
              Expanded(
                child: _StatTile(
                  icon: Icons.storage_rounded,
                  value: status.bufferLabel ?? '…',
                  label: 'File cached',
                  accent: status.bufferLabel != null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final h = tv
        ? ShellTokens.streamLoadingStatsDividerHeightTv
        : ShellTokens.streamLoadingStatsDividerHeight;
    final m = tv
        ? ShellTokens.streamLoadingStatsDividerMarginTv
        : ShellTokens.streamLoadingStatsDividerMargin;
    return Container(
      width: 1,
      height: h,
      margin: EdgeInsets.symmetric(horizontal: m),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final iconSize = tv
        ? ShellTokens.streamLoadingStatsIconSizeTv
        : ShellTokens.streamLoadingStatsIconSize;
    final iconGap = tv
        ? ShellTokens.streamLoadingStatsIconGapTv
        : ShellTokens.streamLoadingStatsIconGap;
    final valueSize = tv
        ? ShellTokens.streamLoadingStatsValueFontSizeTv
        : ShellTokens.streamLoadingStatsValueFontSize;
    final valueGap = tv
        ? ShellTokens.streamLoadingStatsValueGapTv
        : ShellTokens.streamLoadingStatsValueGap;
    final labelSize = tv
        ? ShellTokens.streamLoadingStatsLabelFontSizeTv
        : ShellTokens.streamLoadingStatsLabelFontSize;
    final valueColor = accent
        ? AppTheme.primaryColor
        : Colors.white.withValues(alpha: 0.9);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        SizedBox(height: iconGap),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: valueSize,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: 0.1,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: valueGap),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: labelSize,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0.2,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
