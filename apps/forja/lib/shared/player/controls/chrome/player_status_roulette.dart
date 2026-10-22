import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shared/playback/stream_provider_probe.dart';
import 'package:forja/shared/player/controls/menus/player_menu_return_focus.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/loading_state_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/loading_state.dart';

enum StatusRouletteKind { loading, success, failed, info }

/// RFC-045 open pipeline progress (shown even when [pinSource] hides source rows).
const kStreamOpenStatusId = 'stream-open';

enum StreamOpenStatusStage { checking, preparing }

String streamOpenStatusLabel(StreamOpenStatusStage stage) => switch (stage) {
  StreamOpenStatusStage.checking => 'Checking stream…',
  StreamOpenStatusStage.preparing => 'Preparing stream…',
};

void upsertStreamOpenStatus(
  PlayerStatusController controller,
  StreamOpenStatusStage stage,
) {
  // The stream-loading session stays alive until the player route pops.
  // Skipping updates here hid Checking / Preparing for the whole watch.
  controller.upsert(
    kStreamOpenStatusId,
    streamOpenStatusLabel(stage),
    kind: StatusRouletteKind.loading,
  );
}

class StatusRouletteEntry {
  const StatusRouletteEntry({
    required this.id,
    required this.label,
    required this.kind,
    this.highlight = false,
  });

  final String id;
  final String label;
  final StatusRouletteKind kind;
  final bool highlight;
}

class PlayerStatusController extends ChangeNotifier {
  final List<StatusRouletteEntry> _entries = [];
  final Map<String, Timer> _timers = {};

  List<StatusRouletteEntry> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  void upsert(
    String id,
    String label, {
    StatusRouletteKind kind = StatusRouletteKind.loading,
    bool highlight = false,
    Duration? dismissAfter,
  }) {
    final idx = _entries.indexWhere((e) => e.id == id);
    final entry = StatusRouletteEntry(
      id: id,
      label: label,
      kind: kind,
      highlight: highlight,
    );
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
    notifyListeners();
    _timers[id]?.cancel();
    if (dismissAfter != null) {
      _timers[id] = Timer(dismissAfter, () => remove(id));
    }
  }

  void remove(String id) {
    _timers.remove(id)?.cancel();
    final removed = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length != removed) notifyListeners();
  }

  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    if (_entries.isNotEmpty) {
      _entries.clear();
      notifyListeners();
    }
  }

  /// Flash success on active loading rows, then hide after [hold].
  void complete({Duration hold = const Duration(milliseconds: 900)}) {
    var changed = false;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].kind == StatusRouletteKind.loading) {
        _entries[i] = StatusRouletteEntry(
          id: _entries[i].id,
          label: _entries[i].label,
          kind: StatusRouletteKind.success,
          highlight: _entries[i].highlight,
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _timers['_complete'] = Timer(hold, clear);
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

List<StatusRouletteEntry> statusEntriesFromProbes(
  List<StreamProviderProbe> probes,
) {
  return probes
      .where((probe) => probe.status != StreamProviderProbeStatus.pending)
      .map(
        (probe) => StatusRouletteEntry(
          id: probe.id,
          label: probe.label,
          kind: switch (probe.status) {
            StreamProviderProbeStatus.trying => StatusRouletteKind.loading,
            StreamProviderProbeStatus.failed => StatusRouletteKind.failed,
            StreamProviderProbeStatus.success => StatusRouletteKind.success,
            StreamProviderProbeStatus.skippedOnTv => StatusRouletteKind.info,
            StreamProviderProbeStatus.pending => StatusRouletteKind.info,
          },
          highlight: probe.isPreferred,
        ),
      )
      .toList();
}

Listenable playerStatusOverlayListenable(
  PlayerStatusController controller,
  ValueListenable<bool>? bufferingListenable,
) {
  if (bufferingListenable == null) return controller;
  return Listenable.merge([controller, bufferingListenable]);
}

bool playerStatusOverlayVisible(
  PlayerStatusController controller,
  bool buffering,
) {
  return controller.entries.isNotEmpty || buffering;
}

bool isStatusRouletteEntry(StatusRouletteEntry entry) {
  if (entry.id == 'buffering') return true;
  if (entry.id == 'playback-failed') return true;
  if (entry.id == kStreamOpenStatusId) return true;
  if (entry.id.startsWith('source-')) return true;
  if (entry.id.startsWith('provider-')) return true;
  if (entry.id == 'episode-switch') return true;
  return false;
}

List<StatusRouletteEntry> statusRouletteEntries(
  List<StatusRouletteEntry> entries,
) {
  return entries.where(isStatusRouletteEntry).toList();
}

List<StatusRouletteEntry> statusNotificationEntries(
  List<StatusRouletteEntry> entries,
) {
  return entries.where((e) => !isStatusRouletteEntry(e)).toList();
}

double statusNotificationTop(BuildContext context) {
  final top = DesktopWindowChrome.isDesktop
      ? DesktopWindowChrome.topInset(context) + 6
      : MediaQuery.paddingOf(context).top + 6;
  return top + 44 + 6 + 4;
}

const kAirPlayCastingStatusId = 'cast-active';

const kAirPlayCastingStatusEntry = StatusRouletteEntry(
  id: kAirPlayCastingStatusId,
  label: 'Playing on AirPlay',
  kind: StatusRouletteKind.success,
);

/// Top-center notice while AirPlay owns playback (no status controller needed).
class PlayerAirPlayCastingNotice extends StatelessWidget {
  const PlayerAirPlayCastingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CastingService.instance.airPlayActive,
      builder: (context, active, _) {
        if (!active) return const SizedBox.shrink();
        return Positioned(
          top: statusNotificationTop(context),
          left: 56,
          right: 56,
          child: const IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: StatusNotificationView(
                entries: [kAirPlayCastingStatusEntry],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Terminal failure copy when the failed roulette row carries none.
const String kPlayerStreamFailedLabel = 'Failed to stream';

/// Active roulette row — the first loading entry, else the last one.
StatusRouletteEntry? activeStatusRouletteEntry(
  List<StatusRouletteEntry> entries,
) {
  for (final entry in entries) {
    if (entry.kind == StatusRouletteKind.loading) return entry;
  }
  return entries.isNotEmpty ? entries.last : null;
}

class PlayerStatusOverlay extends StatelessWidget {
  const PlayerStatusOverlay({
    super.key,
    required this.controller,
    this.bufferingListenable,
    this.header = 'Checking sources',
    this.playbackStarted = true,
    this.failed = false,
    this.onRetry,
    this.onBack,
    this.tvFocusable = false,
    this.failedRetryFocusNode,
    this.onFailedStageUp,
  });

  final PlayerStatusController controller;
  final ValueListenable<bool>? bufferingListenable;
  final String header;

  /// False until the first frame: a centered indicator with the active
  /// source label joins the right-side roulette, so a black screen is never
  /// the only feedback while a stream opens. Hidden once true.
  final bool playbackStarted;

  /// Terminal failure (sources exhausted): centered message + Retry / Back.
  /// Needs [onRetry]; the right-side failed row stays as the detail.
  final bool failed;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  /// D-pad focusable Retry / Back (leanback). Pointer buttons otherwise.
  final bool tvFocusable;

  /// Host-owned node for the centered Retry so chrome edges (↓ from the top
  /// bar) can land on it. Owned by the stage when null.
  final FocusNode? failedRetryFocusNode;

  /// D-pad ↑ from the centered Retry / Back — host routes it into its chrome.
  final VoidCallback? onFailedStageUp;

  bool get _centerFailure => failed && onRetry != null;

  List<StatusRouletteEntry> _rouletteEntries(bool buffering) {
    final fromController = statusRouletteEntries(controller.entries);
    if (fromController.isNotEmpty) return fromController;
    if (buffering) {
      return const [
        StatusRouletteEntry(
          id: 'buffering',
          label: 'Buffering…',
          kind: StatusRouletteKind.loading,
        ),
      ];
    }
    return const [];
  }

  List<StatusRouletteEntry> _notificationEntries({
    required bool airPlayActive,
  }) {
    final fromController = statusNotificationEntries(
      controller.entries,
    ).where((e) => e.id != kAirPlayCastingStatusId && e.id != 'cast').toList();
    if (airPlayActive) {
      // Last wins in [StatusNotificationView] — keep cast notice on top.
      return [...fromController, kAirPlayCastingStatusEntry];
    }
    return fromController;
  }

  @override
  Widget build(BuildContext context) {
    Widget buildOverlay(bool buffering, bool airPlayActive) {
      // Local mpv keeps buffering while AirPlay owns playback — hide that.
      final rouletteEntries = _rouletteEntries(buffering && !airPlayActive);
      final notificationEntries = _notificationEntries(
        airPlayActive: airPlayActive,
      );
      if (rouletteEntries.isEmpty &&
          notificationEntries.isEmpty &&
          !_centerFailure) {
        return const SizedBox.shrink();
      }

      final hasRouletteProgress = controller.entries.any(isStatusRouletteEntry);
      final overlayHeader = hasRouletteProgress ? header : 'Buffering';
      final tv = ShellPaintScope.usesTvDensityOf(context);
      final edgeInset = tv
          ? ShellTokens.playerStatusEdgeInsetTv
          : ShellTokens.playerStatusEdgeInset;
      final active = activeStatusRouletteEntry(rouletteEntries);
      final centerLoading =
          !playbackStarted &&
          !_centerFailure &&
          active != null &&
          active.kind == StatusRouletteKind.loading;
      final failedRow = _centerFailure
          ? rouletteEntries.lastWhere(
              (e) => e.kind == StatusRouletteKind.failed,
              orElse: () => const StatusRouletteEntry(
                id: 'playback-failed',
                label: kPlayerStreamFailedLabel,
                kind: StatusRouletteKind.failed,
              ),
            )
          : null;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (centerLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: ForjaLoadingState(
                  title: overlayHeader,
                  detail: active.label,
                ),
              ),
            ),
          if (failedRow != null)
            Positioned.fill(
              child: PlayerStreamFailedStage(
                // Manual source / stream switch aborts upsert the failed row
                // with the source title — that is the detail, never the title.
                message: kPlayerStreamFailedLabel,
                detail: failedRow.label == kPlayerStreamFailedLabel
                    ? null
                    : failedRow.label,
                onRetry: onRetry!,
                onBack: onBack,
                tvFocusable: tvFocusable,
                retryFocusNode: failedRetryFocusNode,
                onUpEdge: onFailedStageUp,
              ),
            ),
          if (rouletteEntries.isNotEmpty)
            Positioned(
              top: 0,
              right: edgeInset,
              bottom: 0,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusRouletteView(
                    entries: rouletteEntries,
                    header: overlayHeader,
                  ),
                ),
              ),
            ),
          if (notificationEntries.isNotEmpty)
            Positioned(
              top: statusNotificationTop(context),
              left: 56,
              right: 56,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: StatusNotificationView(entries: notificationEntries),
                ),
              ),
            ),
        ],
      );
    }

    final airPlay = CastingService.instance.airPlayActive;
    if (bufferingListenable == null) {
      return ListenableBuilder(
        listenable: Listenable.merge([controller, airPlay]),
        builder: (context, _) => buildOverlay(false, airPlay.value),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        playerStatusOverlayListenable(controller, bufferingListenable),
        airPlay,
      ]),
      builder: (context, _) =>
          buildOverlay(bufferingListenable!.value, airPlay.value),
    );
  }
}

/// Centered terminal failure: message + Retry / Back.
///
/// Leanback: both controls are D-pad focusable, Retry takes focus when the
/// stage appears, ←/→ move between them. The stage sits under a
/// `player-chrome` focus label so [PlayerTvKeyScope] leaves D-pad keys to
/// focus traversal instead of re-claiming Play.
class PlayerStreamFailedStage extends StatefulWidget {
  const PlayerStreamFailedStage({
    super.key,
    required this.message,
    this.detail,
    required this.onRetry,
    this.onBack,
    this.tvFocusable = false,
    this.retryFocusNode,
    this.onUpEdge,
  });

  final String message;

  /// Source / stream that was being opened when it failed.
  final String? detail;
  final VoidCallback onRetry;
  final VoidCallback? onBack;
  final bool tvFocusable;
  final FocusNode? retryFocusNode;

  /// D-pad ↑ from Retry / Back (TV) — host routes into the top bar.
  final VoidCallback? onUpEdge;

  static const String retryLabel = 'Retry';
  static const String backLabel = 'Back';

  @override
  State<PlayerStreamFailedStage> createState() =>
      _PlayerStreamFailedStageState();
}

class _PlayerStreamFailedStageState extends State<PlayerStreamFailedStage> {
  FocusNode? _ownedRetryFocus;
  final FocusNode _backFocus = FocusNode(debugLabel: 'player-failed-back');

  FocusNode get _retryFocus =>
      widget.retryFocusNode ??
      (_ownedRetryFocus ??= FocusNode(debugLabel: 'player-failed-retry'));

  @override
  void initState() {
    super.initState();
    if (widget.tvFocusable) _claimRetryFocus();
  }

  /// The chrome reveal that accompanies a failure makes the TV key scope
  /// re-claim Play a frame later; [playerChromeLandFocus] holds that off so
  /// Retry keeps the remote.
  void _claimRetryFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      playerChromeLandFocus(_retryFocus);
    });
  }

  @override
  void dispose() {
    _ownedRetryFocus?.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  Widget _face(BuildContext context, String label, {required bool primary}) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final padH = tv
        ? LoadingStateTokens.actionPadHTv
        : LoadingStateTokens.actionPadH;
    final padV = tv
        ? LoadingStateTokens.actionPadVTv
        : LoadingStateTokens.actionPadV;
    final fs = tv
        ? LoadingStateTokens.actionFontSizeTv
        : LoadingStateTokens.actionFontSize;
    final radius = tv
        ? LoadingStateTokens.actionRadiusTv
        : LoadingStateTokens.actionRadius;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: primary
              ? ForjaShellColors.cinematic.textPrimary
              : ForjaShellColors.ghostBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ForjaShellColors.cinematic.textPrimary,
          fontSize: fs,
          fontWeight: FontWeight.w600,
          letterSpacing: LoadingStateTokens.actionLetterSpacing,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    required bool primary,
    required FocusNode focusNode,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
  }) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final radius = tv
        ? LoadingStateTokens.actionRadiusTv
        : LoadingStateTokens.actionRadius;
    if (!widget.tvFocusable) {
      return Button(
        variant: ButtonVariant.outline,
        label: label,
        onPressed: onTap,
        fontSize: tv
            ? LoadingStateTokens.actionFontSizeTv
            : LoadingStateTokens.actionFontSize,
        padding: EdgeInsets.symmetric(
          horizontal: tv
              ? LoadingStateTokens.actionPadHTv
              : LoadingStateTokens.actionPadH,
        ),
      );
    }
    return shellFocusableTap(
      context: context,
      focusNode: focusNode,
      onTap: onTap,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      onUpEdge: widget.onUpEdge,
      child: _face(context, label, primary: primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = ShellPaintScope.usesTvDensityOf(context)
        ? LoadingStateTokens.actionGapTv
        : LoadingStateTokens.actionGap;
    final onBack = widget.onBack;
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _action(
          context,
          PlayerStreamFailedStage.retryLabel,
          widget.onRetry,
          primary: true,
          focusNode: _retryFocus,
          onRightEdge: onBack != null && _backFocus.canRequestFocus
              ? _backFocus.requestFocus
              : null,
        ),
        if (onBack != null) ...[
          SizedBox(width: gap),
          _action(
            context,
            PlayerStreamFailedStage.backLabel,
            onBack,
            primary: false,
            focusNode: _backFocus,
            onLeftEdge: _retryFocus.requestFocus,
          ),
        ],
      ],
    );
    final stage = ForjaLoadingState(
      icon: Icons.error_outline_rounded,
      iconColor: ForjaShellColors.cinematic.textSecondary,
      title: widget.message,
      detail: widget.detail,
      hint: widget.tvFocusable && policy.leanbackOnly && onBack != null
          ? 'Press Back to leave'
          : null,
      actions: actions,
    );
    if (!widget.tvFocusable) return stage;
    return Focus(
      debugLabel: 'player-chrome',
      canRequestFocus: false,
      skipTraversal: true,
      child: stage,
    );
  }
}

class StatusNotificationView extends StatelessWidget {
  const StatusNotificationView({super.key, required this.entries});

  final List<StatusRouletteEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final active = entries.last;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _StatusRouletteRow(
        key: ValueKey('${active.id}-${active.kind.name}'),
        entry: active,
        centered: true,
      ),
    );
  }
}

class StatusRouletteView extends StatelessWidget {
  const StatusRouletteView({
    super.key,
    required this.entries,
    required this.header,
  });

  final List<StatusRouletteEntry> entries;
  final String header;

  StatusRouletteEntry? get _activeEntry => activeStatusRouletteEntry(entries);

  StatusRouletteEntry? get _previousEntry {
    final active = _activeEntry;
    if (active == null) return null;
    final idx = entries.indexWhere((e) => e.id == active.id);
    if (idx <= 0) return null;
    return entries[idx - 1];
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeEntry;
    if (active == null) return const SizedBox.shrink();

    final tv = ShellPaintScope.usesTvDensityOf(context);
    final previous = _previousEntry;
    final checkedCount = entries
        .where((e) => e.kind != StatusRouletteKind.loading)
        .length;
    final totalCount = entries.length;
    final progress = totalCount > 0 ? checkedCount / totalCount : 0.0;
    final workActive = active.kind == StatusRouletteKind.loading;

    final columnWidth = tv
        ? ShellTokens.playerStatusColumnWidthTv
        : ShellTokens.playerStatusColumnWidth;
    final headerSize = tv
        ? ShellTokens.playerStatusHeaderFontSizeTv
        : ShellTokens.playerStatusHeaderFontSize;
    final slotHeight = tv
        ? ShellTokens.playerStatusRouletteSlotHeightTv
        : ShellTokens.playerStatusRouletteSlotHeight;
    final headerGap = tv
        ? ShellTokens.playerStatusHeaderGapTv
        : ShellTokens.playerStatusHeaderGap;
    final progressGap = tv
        ? ShellTokens.playerStatusProgressGapTv
        : ShellTokens.playerStatusProgressGap;
    final barHeight = tv
        ? ShellTokens.playerStatusProgressHeightTv
        : ShellTokens.playerStatusProgressHeight;
    final barWidth = tv
        ? ShellTokens.playerStatusProgressWidthTv
        : ShellTokens.playerStatusProgressWidth;

    return SizedBox(
      width: columnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            header,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: ForjaShellColors.cinematic.textSecondary,
              fontSize: headerSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: headerGap),
          SizedBox(
            height: slotHeight,
            width: columnWidth,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.centerRight,
                clipBehavior: Clip.hardEdge,
                children: [
                  if (previous != null &&
                      previous.kind != StatusRouletteKind.loading)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.only(top: tv ? 2 : 4),
                        child: _StatusRouletteRow(
                          entry: previous,
                          dimmed: true,
                          compact: true,
                        ),
                      ),
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previousChildren) => Stack(
                      alignment: Alignment.centerRight,
                      clipBehavior: Clip.hardEdge,
                      children: [...previousChildren, ?current],
                    ),
                    transitionBuilder: (child, animation) {
                      final slide =
                          Tween<Offset>(
                            begin: const Offset(0, 0.55),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );
                      return ClipRect(
                        child: SlideTransition(
                          position: slide,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _StatusRouletteRow(
                      key: ValueKey('${active.id}-${active.kind.name}'),
                      entry: active,
                      showSpinner: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: progressGap),
          SizedBox(
            width: barWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barHeight),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: workActive ? null : (value > 0 ? value : null),
                  minHeight: barHeight,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRouletteRow extends StatelessWidget {
  const _StatusRouletteRow({
    super.key,
    required this.entry,
    this.dimmed = false,
    this.compact = false,
    this.centered = false,
    this.showSpinner = true,
  });

  final StatusRouletteEntry entry;
  final bool dimmed;
  final bool compact;
  final bool centered;

  /// Inline spinner beside the label. Off for CHECKING SOURCES — the bar below
  /// already shows work in progress.
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final isLoading = entry.kind == StatusRouletteKind.loading;
    final isFailed = entry.kind == StatusRouletteKind.failed;
    final alpha = dimmed ? 0.45 : (isFailed ? 0.65 : 1.0);
    final labelSize = compact
        ? (tv
              ? ShellTokens.playerStatusLabelFontSizeCompactTv
              : ShellTokens.playerStatusLabelFontSizeCompact)
        : (tv
              ? ShellTokens.playerStatusLabelFontSizeTv
              : ShellTokens.playerStatusLabelFontSize);
    final spinnerSize = tv
        ? ShellTokens.playerStatusSpinnerSizeTv
        : ShellTokens.playerStatusSpinnerSize;
    final spinnerStroke = tv
        ? ShellTokens.playerStatusSpinnerStrokeTv
        : ShellTokens.playerStatusSpinnerStroke;
    final iconSize = tv
        ? ShellTokens.playerStatusIconSizeTv
        : ShellTokens.playerStatusIconSize;
    final starSize = compact ? (tv ? 9.0 : 11.0) : (tv ? 11.0 : 14.0);
    final gap = tv ? 6.0 : 10.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.end,
      children: [
        if (!compact && !isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: _StatusIcon(
              kind: entry.kind,
              dimmed: dimmed,
              size: iconSize,
            ),
          ),
          SizedBox(width: gap),
        ],
        if (entry.highlight && !dimmed) ...[
          Icon(
            Icons.star_rounded,
            size: starSize,
            color: Colors.amber.withValues(alpha: isFailed ? 0.4 : 0.85),
          ),
          SizedBox(width: tv ? 3 : 4),
        ],
        Flexible(
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: alpha),
              fontSize: labelSize,
              fontWeight: isLoading && !dimmed
                  ? FontWeight.w600
                  : FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        if (isLoading && !dimmed && showSpinner) ...[
          SizedBox(width: gap),
          SizedBox(
            width: spinnerSize,
            height: spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: spinnerStroke,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.kind,
    this.dimmed = false,
    required this.size,
  });

  final StatusRouletteKind kind;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final alpha = dimmed ? 0.35 : 1.0;
    switch (kind) {
      case StatusRouletteKind.loading:
        return CircularProgressIndicator(
          strokeWidth: size > 14 ? 2.0 : 1.6,
          color: Colors.white.withValues(alpha: 0.9 * alpha),
        );
      case StatusRouletteKind.failed:
        return Icon(
          Icons.close_rounded,
          size: size,
          color: Colors.red.shade400.withValues(alpha: alpha),
        );
      case StatusRouletteKind.success:
        return Icon(
          Icons.check_rounded,
          size: size,
          color: const Color(0xFF22C55E).withValues(alpha: alpha),
        );
      case StatusRouletteKind.info:
        return Icon(
          Icons.info_outline_rounded,
          size: size,
          color: Colors.white.withValues(alpha: 0.7 * alpha),
        );
    }
  }
}
