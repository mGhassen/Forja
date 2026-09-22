import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/playback/open/stream_loading.dart';
import 'package:forja/shared/playback/direct_stream_loading_panel.dart';
import 'package:forja/shared/playback/resolve_failure_view.dart';
import 'package:forja/shared/playback/stream_provider_probe.dart';
import 'package:forja/shared/player/entry/player_metadata.dart';
import 'package:forja/shared/player/sources/torrent/torrent_loading_status_panel.dart';

const loadingOverlayFadeOutDuration = Duration(milliseconds: 750);

/// [RouteSettings.name] for stream-loading hosts/dialogs under the player.
///
/// Anime / Asian Drama hosts stay mounted under the player for Source reload
/// during playback. On exit, strip them **before** popping the player
/// ([dismissActiveLoadingOverlayRoute]) so Back never paints resolve UI.
const loadingOverlayRouteName = 'loading_overlay';

NavigatorState? _activeLoadingOverlayNavigator;
Route<dynamic>? _activeLoadingOverlayRoute;

/// Remember the stream-loading route so player exit can strip it without a
/// visible flash (and without disposing it mid-playback).
void registerLoadingOverlayRoute(
  NavigatorState navigator,
  Route<dynamic>? route,
) {
  if (route == null) return;
  _activeLoadingOverlayNavigator = navigator;
  _activeLoadingOverlayRoute = route;
}

/// Drop the registration when the loading route is dismissed on its own.
void clearLoadingOverlayRouteRegistration(Route<dynamic>? route) {
  if (route == null) return;
  if (!identical(_activeLoadingOverlayRoute, route)) return;
  _activeLoadingOverlayNavigator = null;
  _activeLoadingOverlayRoute = null;
}

/// Strip the stream-loading route so Back returns to details, not resolve UI.
///
/// Call **before** popping [PlayerScreen]. [Navigator.removeRoute] yanks the
/// loading host from under the player without revealing it; popping first
/// paints one frame of the resolve roulette (issue 101).
///
/// Uses the registered [Route] when present, then falls back to
/// [Navigator.popUntil] if loading somehow became current. Retries next frame
/// when the navigator was locked mid-transition.
void dismissActiveLoadingOverlayRoute([NavigatorState? navigator]) {
  final registeredNav = _activeLoadingOverlayNavigator;
  final route = _activeLoadingOverlayRoute;
  _activeLoadingOverlayNavigator = null;
  _activeLoadingOverlayRoute = null;

  final nav = navigator ?? registeredNav;
  if (nav == null) return;

  void strip() {
    if (!nav.mounted) return;
    if (route != null) {
      _removeLoadingOverlayRoute(nav, route);
    }
    try {
      // If loading is current (player already gone / missed removeRoute), pop
      // it. While the player is still on top the predicate is already true —
      // no-op, which is what we want after a successful under-player remove.
      nav.popUntil(
        (route) => route.settings.name != loadingOverlayRouteName,
      );
    } catch (_) {
      // Navigator locked or disposed mid-exit - post-frame retry below.
    }
  }

  strip();
  WidgetsBinding.instance.addPostFrameCallback((_) => strip());
}

Future<T?> showLoadingOverlayDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  /// Same navigator as [AppRouter.openPlayer] so Back cannot leave a loading
  /// dialog stranded on the shell overlay under a root player route.
  bool useRootNavigator = true,
}) {
  final hostContext = context;
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: false,
    barrierDismissible: false,
    barrierColor: Colors.black,
    routeSettings: const RouteSettings(name: loadingOverlayRouteName),
    builder: (dialogContext) {
      final navigator = Navigator.of(dialogContext);
      final route = ModalRoute.of(dialogContext);
      registerLoadingOverlayRoute(navigator, route);
      // Root-navigator dialogs sit above the shell route - rehost so TV
      // Cancel / server-list focus uses [ShellInputPolicy.tv].
      return ShellScope.rehost(hostContext, builder(dialogContext));
    },
  );
}

void _removeLoadingOverlayRoute(
  NavigatorState navigator,
  Route<dynamic>? route,
) {
  if (!navigator.mounted) return;
  if (route != null) {
    if (!route.isActive) {
      clearLoadingOverlayRouteRegistration(route);
      return;
    }
    navigator.removeRoute(route);
    clearLoadingOverlayRouteRegistration(route);
    return;
  }
  if (navigator.canPop()) navigator.pop();
}

/// Removes the loading dialog without popping whatever route was pushed above it.
///
/// Safe to call twice (cancel + async cleanup). Tries synchronously, then
/// retries on the next frame if the navigator was locked mid-transition.
void dismissLoadingOverlayRoute(BuildContext loadingDialogContext) {
  if (!loadingDialogContext.mounted) return;
  final navigator = Navigator.of(loadingDialogContext);
  final route = ModalRoute.of(loadingDialogContext);
  _removeLoadingOverlayRoute(navigator, route);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _removeLoadingOverlayRoute(navigator, route);
  });
}

/// Dispose overlay notifiers after [dismissLoadingOverlayRoute]'s post-frame
/// remove + [LoadingOverlay.dispose] removeListener - never dispose while the
/// dialog is still listening (red-screens as "used after being disposed").
///
/// Idempotent: cancel + `finally` paths often schedule dispose twice.
void disposeLoadingOverlayNotifiers(Iterable<ChangeNotifier> notifiers) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final n in notifiers) {
        try {
          n.dispose();
        } on FlutterError {
          // Already disposed.
        }
      }
    });
  });
}

/// Fades the loading overlay out while the player route fades in underneath.
///
/// Captures the loading [Route] before [openPlayer] and strips it from under
/// the player (fade end + player close). Player Back alone never pops this
/// dialog - leaving it mounted is what stranded users on the loading screen.
Future<T?> crossfadeLoadingOverlayToPlayer<T>({
  required BuildContext loadingDialogContext,
  ValueNotifier<bool>? fadeOutNotifier,
  Future<void> Function()? beforeFade,
  required Future<T?> Function() openPlayer,
}) async {
  if (beforeFade != null) await beforeFade();
  fadeOutNotifier?.value = true;

  if (!loadingDialogContext.mounted) {
    return openPlayer();
  }
  // Capture before the player push - dialog context can unmount after remove.
  final navigator = Navigator.of(loadingDialogContext);
  final route = ModalRoute.of(loadingDialogContext);
  registerLoadingOverlayRoute(navigator, route);

  void dismiss() => _removeLoadingOverlayRoute(navigator, route);

  final playerFuture = openPlayer();
  // Movies/TV: strip the dialog under the player during the fade. Anime /
  // Asian Drama keep their host registered until player Back calls
  // [dismissActiveLoadingOverlayRoute] (Source reload needs the host alive).
  WidgetsBinding.instance.addPostFrameCallback((_) => dismiss());
  unawaited(
    Future<void>.delayed(loadingOverlayFadeOutDuration).then((_) => dismiss()),
  );

  try {
    return await playerFuture;
  } finally {
    dismiss();
  }
}

class LoadingOverlay extends StatefulWidget {
  final Movie movie;
  final String? message;
  final ValueNotifier<String>? messageNotifier;
  final ValueNotifier<StreamLoadingKind>? kindNotifier;
  final ValueNotifier<TorrentLoadingStatus?>? torrentStatusNotifier;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;
  final ValueNotifier<bool>? fadeOutNotifier;

  /// When non-null, the overlay swaps the progress strip for a failure panel.
  final ValueNotifier<ResolveFailure?>? failureNotifier;
  final String? subtitle;
  final String? recheckBanner;

  /// Mid-resolve reload strip (anime stale cache). Prefer friendly labels.
  final bool showReloadButton;
  final String reloadLabel;
  final String reloadHint;
  final VoidCallback? onReload;
  final VoidCallback? onCancel;

  /// Tap a waiting / down / checking server in the list to prioritize it.
  /// Auto checks that provider first; if it misses, the race continues.
  final ValueChanged<String>? onManualCheckProvider;

  const LoadingOverlay({
    super.key,
    required this.movie,
    this.message,
    this.messageNotifier,
    this.kindNotifier,
    this.torrentStatusNotifier,
    this.providerProbesNotifier,
    this.fadeOutNotifier,
    this.failureNotifier,
    this.subtitle,
    this.recheckBanner,
    this.showReloadButton = false,
    this.reloadLabel = 'Search again',
    this.reloadHint = 'That saved link is no longer working',
    this.onReload,
    this.onCancel,
    this.onManualCheckProvider,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with TickerProviderStateMixin {
  /// Space reserved at the bottom for progress / cancel so the title logo
  /// centers in the clear area above instead of overlapping it.
  static const double _statusStripReserveDesktop =
      ShellTokens.streamLoadingStatusStripReserve;

  late AnimationController _pulseController;
  late AnimationController _fadeOutController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeOutAnimation;
  late String _message;
  StreamLoadingKind _kind = StreamLoadingKind.direct;
  TorrentLoadingStatus? _torrentStatus;
  List<StreamProviderProbe> _probes = const [];
  bool _providerListOpen = false;
  ResolveFailure? _failure;
  final FocusNode _providersButtonFocus =
      FocusNode(debugLabel: 'loading-providers');
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'loading-cancel');
  final List<FocusNode> _providerRowFocus = [];
  final ScrollController _providerListScroll = ScrollController();
  String? _fetchedLogoUrl;

  double _statusStripReserve(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return tv
        ? ShellTokens.streamLoadingStatusStripReserveTv
        : _statusStripReserveDesktop;
  }

  double _logoBottomReserve(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final base = _statusStripReserve(context);
    if (!_providerListOpen) return base;
    final extra = tv
        ? ShellTokens.streamLoadingProviderListExtraTv
        : ShellTokens.streamLoadingProviderListExtra;
    return base + extra;
  }

  bool get _showingFailure => _failure != null;

  @override
  void initState() {
    super.initState();
    _message = widget.messageNotifier?.value ??
        widget.message ??
        'Starting stream';
    _kind = widget.kindNotifier?.value ?? StreamLoadingKind.direct;
    _torrentStatus = widget.torrentStatusNotifier?.value;
    _failure = widget.failureNotifier?.value;
    widget.messageNotifier?.addListener(_onMessageChanged);
    widget.kindNotifier?.addListener(_onKindChanged);
    widget.torrentStatusNotifier?.addListener(_onTorrentStatusChanged);
    widget.providerProbesNotifier?.addListener(_onProbesChanged);
    widget.fadeOutNotifier?.addListener(_onFadeOutRequested);
    widget.failureNotifier?.addListener(_onFailureChanged);
    _probes = widget.providerProbesNotifier?.value ?? const [];
    _syncProviderRowFocusNodes();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
      value: 1.0,
    );
    _fadeOutAnimation = CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeOut,
    );
    if (_showingFailure) {
      _pulseController.stop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusInitialAction();
    });
    unawaited(_fetchLogoIfNeeded());
  }

  Future<void> _fetchLogoIfNeeded() async {
    if (_logoImageUrl != null) return;
    final movieId = widget.movie.id;
    final url = await resolveTmdbLogoImageUrl(widget.movie);
    if (!mounted || widget.movie.id != movieId) return;
    setState(() => _fetchedLogoUrl = url);
  }

  void _syncProviderRowFocusNodes() {
    final need = _probes.length;
    while (_providerRowFocus.length < need) {
      _providerRowFocus.add(
        FocusNode(debugLabel: 'loading-provider-${_providerRowFocus.length}'),
      );
    }
    while (_providerRowFocus.length > need) {
      _providerRowFocus.removeLast().dispose();
    }
  }

  void _focusInitialAction() {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    // Leanback only — desktop keeps pointer-first; don't steal mouse focus.
    if (!policy.useFocusableMoodChips || policy.scaleOnHover) return;
    if (_showProviderProbes && _providersButtonFocus.canRequestFocus) {
      _providersButtonFocus.requestFocus();
      return;
    }
    if (_cancelFocus.canRequestFocus) {
      _cancelFocus.requestFocus();
    }
  }

  void _focusFirstProviderRow() {
    _syncProviderRowFocusNodes();
    for (var i = 0; i < _probes.length; i++) {
      if (!_canManualCheck(_probes[i])) continue;
      _claimProviderRow(i);
      return;
    }
  }

  /// Enter the server list from Cancel / servers (below the panel).
  void _focusLastProviderRow() {
    _syncProviderRowFocusNodes();
    for (var i = _probes.length - 1; i >= 0; i--) {
      if (!_canManualCheck(_probes[i])) continue;
      _claimProviderRow(i);
      return;
    }
  }

  /// Focus a provider row, scrolling the lazy list so the node is attached.
  void _claimProviderRow(int index) {
    if (index < 0 || index >= _providerRowFocus.length) return;
    final node = _providerRowFocus[index];
    if (node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    if (!_providerListScroll.hasClients) return;
    // Row padding 10*2 + ~20 text + 1 separator ≈ 49.
    const rowExtent = 49.0;
    final target = (index * rowExtent).clamp(
      0.0,
      _providerListScroll.position.maxScrollExtent,
    );
    _providerListScroll.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  void _toggleProviderList() {
    setState(() => _providerListOpen = !_providerListOpen);
    if (_providerListOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusFirstProviderRow();
      });
    }
  }

  void _focusNextProviderRow(int index) {
    for (var i = index + 1; i < _probes.length; i++) {
      if (!_canManualCheck(_probes[i])) continue;
      _claimProviderRow(i);
      return;
    }
    // Last provider → back to providers button.
    if (_providersButtonFocus.canRequestFocus) {
      _providersButtonFocus.requestFocus();
    }
  }

  void _focusPrevProviderRow(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (!_canManualCheck(_probes[i])) continue;
      _claimProviderRow(i);
      return;
    }
    // First provider → back to servers / cancel row.
    if (_providersButtonFocus.canRequestFocus) {
      _providersButtonFocus.requestFocus();
    } else if (_cancelFocus.canRequestFocus) {
      _cancelFocus.requestFocus();
    }
  }

  void _onMessageChanged() {
    final notifier = widget.messageNotifier;
    if (notifier == null) return;
    late final String next;
    try {
      next = notifier.value;
    } on FlutterError {
      return;
    }
    if (next != _message && mounted) {
      setState(() => _message = next);
    }
  }

  void _onKindChanged() {
    final notifier = widget.kindNotifier;
    if (notifier == null) return;
    late final StreamLoadingKind next;
    try {
      next = notifier.value;
    } on FlutterError {
      return;
    }
    if (next != _kind && mounted) {
      setState(() => _kind = next);
    }
  }

  void _onTorrentStatusChanged() {
    final notifier = widget.torrentStatusNotifier;
    if (notifier == null) return;
    late final TorrentLoadingStatus? next;
    try {
      next = notifier.value;
    } on FlutterError {
      return;
    }
    if (next != _torrentStatus && mounted) {
      setState(() => _torrentStatus = next);
    }
  }

  void _onProbesChanged() {
    final next = widget.providerProbesNotifier?.value;
    if (next != null && mounted) {
      final hadProbes = _probes.isNotEmpty;
      setState(() {
        _probes = next;
        _syncProviderRowFocusNodes();
      });
      // Probes arrive after first paint - claim Cancel / servers once they exist.
      if (!hadProbes && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _showingFailure) return;
          _focusInitialAction();
        });
      }
    }
  }

  void _onFailureChanged() {
    if (!mounted) return;
    final next = widget.failureNotifier?.value;
    setState(() => _failure = next);
    if (next != null) {
      _pulseController.stop();
      // ResolveFailurePanel autofocuses Try again / Close after this rebuild.
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _showingFailure) return;
        _focusInitialAction();
      });
    }
  }

  void _onFadeOutRequested() {
    if (!mounted) return;
    if (widget.fadeOutNotifier?.value == true) {
      _fadeOutController.reverse();
    } else {
      // Player closed before hand-off finished - restore the overlay so
      // Cancel / Reload are visible again (not a blank black route).
      _fadeOutController.forward();
    }
  }

  void _safeRemoveListener(ChangeNotifier? notifier, VoidCallback listener) {
    if (notifier == null) return;
    // Owner may race dispose after dismiss; ChangeNotifier asserts in debug.
    try {
      notifier.removeListener(listener);
    } on FlutterError {
      // Already disposed.
    }
  }

  @override
  void dispose() {
    _safeRemoveListener(widget.messageNotifier, _onMessageChanged);
    _safeRemoveListener(widget.kindNotifier, _onKindChanged);
    _safeRemoveListener(widget.torrentStatusNotifier, _onTorrentStatusChanged);
    _safeRemoveListener(widget.providerProbesNotifier, _onProbesChanged);
    _safeRemoveListener(widget.fadeOutNotifier, _onFadeOutRequested);
    _safeRemoveListener(widget.failureNotifier, _onFailureChanged);
    for (final n in _providerRowFocus) {
      n.dispose();
    }
    _providerListScroll.dispose();
    _providersButtonFocus.dispose();
    _cancelFocus.dispose();
    _pulseController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  bool get _showProviderProbes =>
      _kind == StreamLoadingKind.direct &&
      widget.providerProbesNotifier != null &&
      _probes.isNotEmpty;

  bool get _isTorrentKind => _kind == StreamLoadingKind.torrent;

  bool _canManualCheck(StreamProviderProbe probe) {
    if (widget.onManualCheckProvider == null) return false;
    // Allow tapping CHECKING rows so the user can jump to another server
    // (or re-pin the current one) without waiting for the active probe.
    return probe.status != StreamProviderProbeStatus.skippedOnTv;
  }

  String _probeStatusLabel(StreamProviderProbeStatus status) {
    return switch (status) {
      StreamProviderProbeStatus.pending => 'WAITING',
      StreamProviderProbeStatus.trying => 'CHECKING',
      StreamProviderProbeStatus.success => 'UP',
      StreamProviderProbeStatus.failed => 'DOWN',
      StreamProviderProbeStatus.skippedOnTv => 'SKIPPED',
    };
  }

  Color _probeStatusColor(StreamProviderProbeStatus status) {
    return switch (status) {
      StreamProviderProbeStatus.success => const Color(0xFF22C55E),
      StreamProviderProbeStatus.failed => const Color(0xFFEF4444),
      StreamProviderProbeStatus.trying => AppTheme.primaryColor,
      StreamProviderProbeStatus.skippedOnTv =>
        Colors.white.withValues(alpha: 0.35),
      StreamProviderProbeStatus.pending => Colors.white.withValues(alpha: 0.45),
    };
  }

  Widget _probeStatusGlyph(StreamProviderProbeStatus status) {
    final color = _probeStatusColor(status);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final glyph = tv
        ? ShellTokens.streamLoadingProviderGlyphTv
        : ShellTokens.streamLoadingProviderGlyph;
    final pending = tv
        ? ShellTokens.streamLoadingProviderPendingDotTv
        : ShellTokens.streamLoadingProviderPendingDot;
    return switch (status) {
      StreamProviderProbeStatus.trying => SizedBox(
          width: glyph,
          height: glyph,
          child: CircularProgressIndicator(
            strokeWidth: tv ? 1.6 : 2,
            color: color,
          ),
        ),
      StreamProviderProbeStatus.failed => Icon(
          Icons.cancel_rounded,
          size: ShellPaintScope.iconOf(context, 16),
          color: color,
        ),
      StreamProviderProbeStatus.success => Icon(
          Icons.check_circle_rounded,
          size: ShellPaintScope.iconOf(context, 16),
          color: color,
        ),
      StreamProviderProbeStatus.skippedOnTv => Icon(
          Icons.remove_circle_outline_rounded,
          size: ShellPaintScope.iconOf(context, 16),
          color: color,
        ),
      StreamProviderProbeStatus.pending => Container(
          width: pending,
          height: pending,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
    };
  }

  Widget _optionalResolveBanners() {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final bannerSize = tv
        ? ShellTokens.streamLoadingHintFontSizeTv
        : ShellTokens.streamLoadingHintFontSize;
    final bannerGap = tv
        ? ShellTokens.streamLoadingBannerGapTv
        : ShellTokens.streamLoadingBannerGap;
    final reloadGap = tv
        ? ShellTokens.streamLoadingReloadGapTv
        : ShellTokens.streamLoadingReloadGap;
    final reloadButtonGap = tv
        ? ShellTokens.streamLoadingReloadButtonGapTv
        : ShellTokens.streamLoadingReloadButtonGap;
    final reloadPadH = tv
        ? ShellTokens.streamLoadingReloadButtonPadHTv
        : ShellTokens.streamLoadingReloadButtonPadH;
    final reloadPadV = tv
        ? ShellTokens.streamLoadingReloadButtonPadVTv
        : ShellTokens.streamLoadingReloadButtonPadV;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.recheckBanner != null) ...[
          Text(
            widget.recheckBanner!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.amber.shade200.withValues(alpha: 0.95),
              fontSize: bannerSize,
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: bannerGap),
        ],
        if (widget.showReloadButton) ...[
          Text(
            widget.reloadHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: bannerSize,
              fontWeight: FontWeight.w500,
              height: 1.35,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: reloadGap),
          OutlinedButton.icon(
            onPressed: widget.onReload,
            icon: Icon(
              Icons.refresh_rounded,
              size: ShellPaintScope.iconOf(context, 16),
            ),
            label: Text(widget.reloadLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              padding: EdgeInsets.symmetric(
                horizontal: reloadPadH,
                vertical: reloadPadV,
              ),
              textStyle: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: bannerSize,
              ),
            ),
          ),
          SizedBox(height: reloadButtonGap),
        ],
      ],
    );
  }

  Widget _resolveStatusBody() {
    if (_isTorrentKind && _torrentStatus != null) {
      return TorrentLoadingStatusPanel(status: _torrentStatus!);
    }
    return DirectStreamLoadingPanel(
      message: _message,
      subtitle: widget.subtitle,
      probes: _probes,
    );
  }

  Widget _providerListPanel() {
    _syncProviderRowFocusNodes();
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final maxH = tv
        ? ShellTokens.streamLoadingProviderListMaxHeightTv
        : ShellTokens.streamLoadingProviderListMaxHeight;
    final maxW = tv
        ? ShellTokens.streamLoadingProviderListMaxWidthTv
        : ShellTokens.streamLoadingProviderListMaxWidth;
    final radius = tv
        ? ShellTokens.streamLoadingProviderListRadiusTv
        : ShellTokens.streamLoadingProviderListRadius;
    final listPadV = tv
        ? ShellTokens.streamLoadingProviderListPadVTv
        : ShellTokens.streamLoadingProviderListPadV;
    final rowPadH = tv
        ? ShellTokens.streamLoadingProviderRowPadHTv
        : ShellTokens.streamLoadingProviderRowPadH;
    final rowPadV = tv
        ? ShellTokens.streamLoadingProviderRowPadVTv
        : ShellTokens.streamLoadingProviderRowPadV;
    final glyph = tv
        ? ShellTokens.streamLoadingProviderGlyphTv
        : ShellTokens.streamLoadingProviderGlyph;
    final glyphGap = tv
        ? ShellTokens.streamLoadingProviderGlyphGapTv
        : ShellTokens.streamLoadingProviderGlyphGap;
    final labelSize = tv
        ? ShellTokens.streamLoadingProviderLabelFontSizeTv
        : ShellTokens.streamLoadingProviderLabelFontSize;
    final statusSize = tv
        ? ShellTokens.streamLoadingProviderStatusFontSizeTv
        : ShellTokens.streamLoadingProviderStatusFontSize;
    final star = tv
        ? ShellTokens.streamLoadingProviderStarTv
        : ShellTokens.streamLoadingProviderStar;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH, maxWidth: maxW),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: ListView.separated(
          scrollCacheExtent: ScrollCacheExtent.pixels(4000),
          controller: _providerListScroll,
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: listPadV),
          itemCount: _probes.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final probe = _probes[index];
            final canTap = _canManualCheck(probe);
            final statusColor = _probeStatusColor(probe.status);
            final row = Padding(
              padding: EdgeInsets.symmetric(
                horizontal: rowPadH,
                vertical: rowPadV,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: glyph + 4,
                    height: glyph + 4,
                    child: Center(child: _probeStatusGlyph(probe.status)),
                  ),
                  SizedBox(width: glyphGap),
                  Expanded(
                    child: Text(
                      probe.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canTap
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: labelSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  if (probe.isPreferred) ...[
                    Icon(
                      Icons.star_rounded,
                      size: star,
                      color: Colors.amber.shade200.withValues(alpha: 0.9),
                    ),
                    SizedBox(width: glyphGap * 0.6),
                  ],
                  Text(
                    _probeStatusLabel(probe.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: statusSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
            if (!canTap) return row;
            // Mouse hover + D-pad focus: brand-green tint (same language as
            // player menus) — never a solid green block.
            return _LoadingServerRow(
              focusNode: _providerRowFocus[index],
              onTap: () => widget.onManualCheckProvider!(probe.id),
              onDownEdge: () => _focusNextProviderRow(index),
              onUpEdge: () => _focusPrevProviderRow(index),
              child: row,
            );
          },
        ),
      ),
    );
  }

  Widget _cancelChipFace() {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final padH = tv
        ? ShellTokens.streamLoadingCancelPadHTv
        : ShellTokens.streamLoadingCancelPadH;
    final padV = tv
        ? ShellTokens.streamLoadingCancelPadVTv
        : ShellTokens.streamLoadingCancelPadV;
    final radius = tv
        ? ShellTokens.streamLoadingCancelRadiusTv
        : ShellTokens.streamLoadingCancelRadius;
    final fontSize = tv
        ? ShellTokens.streamLoadingCancelFontSizeTv
        : ShellTokens.streamLoadingCancelFontSize;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        'CANCEL',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _serversChipFace({required bool open}) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final pad = tv
        ? ShellTokens.streamLoadingServersChipPadTv
        : ShellTokens.streamLoadingServersChipPad;
    final radius = tv
        ? ShellTokens.streamLoadingCancelRadiusTv
        : ShellTokens.streamLoadingCancelRadius;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        color: open ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      ),
      child: Icon(
        open ? Icons.layers : Icons.layers_outlined,
        size: ShellPaintScope.iconOf(
          context,
          ShellTokens.playerChromeIconSize,
        ),
        color: Colors.white.withValues(alpha: open ? 0.95 : 0.7),
      ),
    );
  }

  Widget _cancelActionRow() {
    final showListToggle = _showProviderProbes;
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    // Desktop hybrid shares TV D-pad flags but must keep Material hover/click.
    final leanback = policy.useFocusableMoodChips && !policy.scaleOnHover;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final radius = tv
        ? ShellTokens.streamLoadingCancelRadiusTv
        : ShellTokens.streamLoadingCancelRadius;
    final padH = tv
        ? ShellTokens.streamLoadingCancelPadHTv
        : ShellTokens.streamLoadingCancelPadH;
    final padV = tv
        ? ShellTokens.streamLoadingCancelPadVTv
        : ShellTokens.streamLoadingCancelPadV;
    final fontSize = tv
        ? ShellTokens.streamLoadingCancelFontSizeTv
        : ShellTokens.streamLoadingCancelFontSize;
    final chipPad = tv
        ? ShellTokens.streamLoadingServersChipPadTv
        : ShellTokens.streamLoadingServersChipPad;
    final listGap = tv
        ? ShellTokens.streamLoadingProviderListGapTv
        : ShellTokens.streamLoadingProviderListGap;
    final tipSize = tv
        ? ShellTokens.streamLoadingTipFontSizeTv
        : ShellTokens.streamLoadingTipFontSize;
    final tipGap = tv
        ? ShellTokens.streamLoadingProviderTipGapTv
        : ShellTokens.streamLoadingProviderTipGap;
    final actionGap = tv
        ? ShellTokens.streamLoadingActionGapTv
        : ShellTokens.streamLoadingActionGap;

    final cancelButton = leanback
        ? shellFocusableTap(
            context: context,
            focusNode: _cancelFocus,
            onTap: widget.onCancel,
            borderRadius: radius,
            scaleOnFocus: 1.0,
            showFocusBorder: true,
            onRightEdge: showListToggle
                ? () {
                    if (_providersButtonFocus.canRequestFocus) {
                      _providersButtonFocus.requestFocus();
                    }
                  }
                : null,
            onUpEdge: _providerListOpen ? _focusLastProviderRow : null,
            child: _cancelChipFace(),
          )
        : TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.7),
              padding: EdgeInsets.symmetric(
                horizontal: padH,
                vertical: padV,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontFamily: 'Poppins',
              ),
            ),
          );

    if (!showListToggle) return cancelButton;

    final listButton = leanback
        ? shellFocusableTap(
            context: context,
            focusNode: _providersButtonFocus,
            onTap: _toggleProviderList,
            borderRadius: radius,
            scaleOnFocus: 1.0,
            showFocusBorder: true,
            onLeftEdge: () {
              if (_cancelFocus.canRequestFocus) {
                _cancelFocus.requestFocus();
              }
            },
            onUpEdge: _providerListOpen ? _focusLastProviderRow : null,
            child: _serversChipFace(open: _providerListOpen),
          )
        : IconButton(
            onPressed: _toggleProviderList,
            tooltip: _providerListOpen ? 'Hide servers' : 'Show servers',
            style: IconButton.styleFrom(
              foregroundColor: Colors.white.withValues(
                alpha: _providerListOpen ? 0.95 : 0.7,
              ),
              backgroundColor: _providerListOpen
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
              padding: EdgeInsets.all(chipPad),
            ),
            icon: Icon(
              _providerListOpen ? Icons.layers : Icons.layers_outlined,
              size: ShellPaintScope.iconOf(
                context,
                ShellTokens.playerChromeIconSize,
              ),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_providerListOpen) ...[
          _providerListPanel(),
          SizedBox(height: listGap),
          if (widget.onManualCheckProvider != null)
            Text(
              'TAP A SERVER TO CHECK IT FIRST',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: tipSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                fontFamily: 'Poppins',
              ),
            ),
          if (widget.onManualCheckProvider != null) SizedBox(height: tipGap),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            cancelButton,
            SizedBox(width: actionGap),
            listButton,
          ],
        ),
      ],
    );
  }

  String? get _logoImageUrl {
    final fetched = _fetchedLogoUrl;
    if (fetched != null && fetched.isNotEmpty) return fetched;
    return tmdbLogoImageUrlFromPath(widget.movie.logoPath);
  }

  String _resolveBackdropUrl() {
    final path = widget.movie.backdropPath;
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '';
  }

  Widget _titleFallback() {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final padH = tv
        ? ShellTokens.streamLoadingTitlePadHTv
        : ShellTokens.streamLoadingTitlePadH;
    final fontSize = tv
        ? ShellTokens.streamLoadingTitleFontSizeTv
        : ShellTokens.streamLoadingTitleFontSize;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padH),
      child: Text(
        widget.movie.title,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = _resolveBackdropUrl();
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final bottom = tv
        ? ShellTokens.streamLoadingBottomInsetTv
        : ShellTokens.streamLoadingBottomInset;
    final padH = tv
        ? ShellTokens.streamLoadingPadHTv
        : ShellTokens.streamLoadingPadH;
    final spinnerStroke = tv
        ? ShellTokens.streamLoadingSpinnerStrokeTv
        : ShellTokens.streamLoadingSpinnerStroke;
    final spinnerGap = tv
        ? ShellTokens.streamLoadingSpinnerGapTv
        : ShellTokens.streamLoadingSpinnerGap;
    final cancelGap = _showProviderProbes
        ? (tv
            ? ShellTokens.streamLoadingCancelGapWithProbesTv
            : ShellTokens.streamLoadingCancelGapWithProbes)
        : (tv
            ? ShellTokens.streamLoadingCancelGapTv
            : ShellTokens.streamLoadingCancelGap);
    final overlay = FadeTransition(
      opacity: _fadeOutAnimation,
      child: Material(
        color: Colors.black,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backdropUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: backdropUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.black),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.black),
                )
              else
                const ColoredBox(color: Colors.black),
              Container(
                color: Colors.black.withValues(
                  alpha: 0.72,
                ),
              ),
              // Logo sits in the upper region so it does not collide with the
              // status/cancel strip at the bottom.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: _logoBottomReserve(context),
                child: Center(
                  child: FadeTransition(
                    opacity: _pulseAnimation,
                    child: _logoImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _logoImageUrl!,
                            width: MediaQuery.of(context).size.width * 0.55,
                            height: MediaQuery.of(context).size.height * 0.28,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            placeholder: (_, _) => _titleFallback(),
                            errorWidget: (_, _, _) => _titleFallback(),
                          )
                        : _titleFallback(),
                  ),
                ),
              ),
              DesktopWindowChrome.overlayDragStrip(),
              Positioned(
                bottom: bottom,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padH),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showingFailure)
                        ResolveFailurePanel(
                          failure: _failure!,
                          compact: true,
                        )
                      else ...[
                        _optionalResolveBanners(),
                        CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: spinnerStroke,
                        ),
                        SizedBox(height: spinnerGap),
                        _resolveStatusBody(),
                      ],
                      if (!_showingFailure && widget.onCancel != null) ...[
                        SizedBox(height: cancelGap),
                        _cancelActionRow(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final escapeAction = _showingFailure
        ? (_failure?.onSecondary ?? _failure?.onPrimary ?? widget.onCancel)
        : widget.onCancel;
    if (escapeAction == null) return overlay;

    // While resolving, trap TV focus in the overlay so Cancel / servers stay
    // reachable. On failure, ResolveFailurePanel owns Try again / Close.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): escapeAction,
      },
      child: _showingFailure
          ? overlay
          : TvOverlayScope(
              // Leanback focus trap only — desktop Material cancel keeps pointer.
              enabled: (ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ??
                      false) &&
                  !(ShellScope.maybeOf(context)?.inputPolicy.scaleOnHover ?? true),
              onDismiss: escapeAction,
              autofocusFirst: false,
              debugLabel: 'loading-overlay',
              child: overlay,
            ),
    );
  }
}

/// Server row on the loading overlay — green tint on mouse hover / D-pad focus.
class _LoadingServerRow extends StatefulWidget {
  const _LoadingServerRow({
    required this.focusNode,
    required this.onTap,
    required this.child,
    this.onDownEdge,
    this.onUpEdge,
  });

  final FocusNode focusNode;
  final VoidCallback onTap;
  final Widget child;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;

  @override
  State<_LoadingServerRow> createState() => _LoadingServerRowState();
}

class _LoadingServerRowState extends State<_LoadingServerRow> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  static final Color _greenTint =
      ForjaShellColors.brandGreen.withValues(alpha: 0.14);

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  @override
  Widget build(BuildContext context) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    return FocusableControl(
      focusNode: widget.focusNode,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      onTap: widget.onTap,
      onDownEdge: widget.onDownEdge,
      onUpEdge: widget.onUpEdge,
      onHoverChange: _setHovered,
      onFocusChange: (f) {
        if (_focused == f) return;
        setState(() => _focused = f);
      },
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) {
          final active = ShellInputPolicy.interactiveActive(
            policy,
            hovered: _hoveredN.value,
            focused: _focused,
            context: context,
          );
          return AnimatedContainer(
            duration: policy.instantFocusChrome
                ? Duration.zero
                : const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: active ? _greenTint : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}
