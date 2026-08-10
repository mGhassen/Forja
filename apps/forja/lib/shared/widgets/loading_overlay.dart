import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';

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
void disposeLoadingOverlayNotifiers(Iterable<ChangeNotifier> notifiers) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final n in notifiers) {
        n.dispose();
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

  /// Tap a waiting / down / up server in the list to check it manually
  /// (cancels Auto order and resolves that provider).
  final ValueChanged<String>? onManualCheckProvider;

  const LoadingOverlay({
    super.key,
    required this.movie,
    this.message,
    this.messageNotifier,
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
  static const double _statusStripReserve = 240;

  late AnimationController _pulseController;
  late AnimationController _fadeOutController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeOutAnimation;
  late String _message;
  List<StreamProviderProbe> _probes = const [];
  bool _providerListOpen = false;
  ResolveFailure? _failure;
  final FocusNode _providersButtonFocus =
      FocusNode(debugLabel: 'loading-providers');
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'loading-cancel');
  final List<FocusNode> _providerRowFocus = [];

  double get _logoBottomReserve =>
      _providerListOpen ? _statusStripReserve + 200 : _statusStripReserve;

  bool get _showingFailure => _failure != null;

  @override
  void initState() {
    super.initState();
    _message = widget.messageNotifier?.value ??
        widget.message?.toUpperCase() ??
        'STARTING STREAM';
    _failure = widget.failureNotifier?.value;
    widget.messageNotifier?.addListener(_onMessageChanged);
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
    final tvFocus =
        ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ?? false;
    if (!tvFocus) return;
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
      final node = _providerRowFocus[i];
      if (node.canRequestFocus) {
        node.requestFocus();
        return;
      }
    }
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
      final next = _providerRowFocus[i];
      if (next.canRequestFocus) {
        next.requestFocus();
        return;
      }
    }
    // Last provider → back to providers button.
    if (_providersButtonFocus.canRequestFocus) {
      _providersButtonFocus.requestFocus();
    }
  }

  void _focusPrevProviderRow(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (!_canManualCheck(_probes[i])) continue;
      final prev = _providerRowFocus[i];
      if (prev.canRequestFocus) {
        prev.requestFocus();
        return;
      }
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
      setState(() => _message = next.toUpperCase());
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
    _safeRemoveListener(widget.providerProbesNotifier, _onProbesChanged);
    _safeRemoveListener(widget.fadeOutNotifier, _onFadeOutRequested);
    _safeRemoveListener(widget.failureNotifier, _onFailureChanged);
    for (final n in _providerRowFocus) {
      n.dispose();
    }
    _providersButtonFocus.dispose();
    _cancelFocus.dispose();
    _pulseController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  bool get _showProviderProbes =>
      widget.providerProbesNotifier != null && _probes.isNotEmpty;

  int get _probeTotal => _probes.length;

  int get _probeChecked => _probes
      .where(
        (p) =>
            p.status != StreamProviderProbeStatus.trying &&
            p.status != StreamProviderProbeStatus.pending,
      )
      .length;

  int get _probeReady => _probes
      .where((p) => p.status == StreamProviderProbeStatus.success)
      .length;

  int get _probeSkipped => _probes
      .where((p) => p.status == StreamProviderProbeStatus.skippedOnTv)
      .length;

  List<String> get _skippedProbeLabels => _probes
      .where((p) => p.status == StreamProviderProbeStatus.skippedOnTv)
      .map((p) => p.label.toUpperCase())
      .toList(growable: false);

  double get _probeProgress =>
      _probeTotal > 0 ? _probeChecked / _probeTotal : 0;

  StreamProviderProbe? get _tryingProbe {
    for (final probe in _probes) {
      if (probe.status == StreamProviderProbeStatus.trying) return probe;
    }
    return null;
  }

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
    return switch (status) {
      StreamProviderProbeStatus.trying => SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
      StreamProviderProbeStatus.failed => Icon(
          Icons.cancel_rounded,
          size: 16,
          color: color,
        ),
      StreamProviderProbeStatus.success => Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: color,
        ),
      StreamProviderProbeStatus.skippedOnTv => Icon(
          Icons.remove_circle_outline_rounded,
          size: 16,
          color: color,
        ),
      StreamProviderProbeStatus.pending => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
    };
  }

  Widget _providerListPanel() {
    _syncProviderRowFocusNodes();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(child: _probeStatusGlyph(probe.status)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      probe.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canTap
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  if (probe.isPreferred) ...[
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.amber.shade200.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _probeStatusLabel(probe.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
            if (!canTap) return row;
            return FocusableControl(
              focusNode: _providerRowFocus[index],
              borderRadius: 8,
              scaleOnFocus: 1.02,
              onTap: () => widget.onManualCheckProvider!(probe.id),
              onDownEdge: () => _focusNextProviderRow(index),
              onUpEdge: () => _focusPrevProviderRow(index),
              child: Material(
                color: Colors.transparent,
                child: row,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cancelChipFace() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        'CANCEL',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _serversChipFace({required bool open}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        color: open ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      ),
      child: Icon(
        open ? Icons.layers : Icons.layers_outlined,
        size: 20,
        color: Colors.white.withValues(alpha: open ? 0.95 : 0.7),
      ),
    );
  }

  Widget _cancelActionRow() {
    final showListToggle = _showProviderProbes;
    final tvFocus =
        ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ?? false;

    final cancelButton = tvFocus
        ? shellFocusableTap(
            context: context,
            focusNode: _cancelFocus,
            onTap: widget.onCancel,
            borderRadius: 24,
            scaleOnFocus: 1.0,
            showFocusBorder: true,
            onRightEdge: showListToggle
                ? () {
                    if (_providersButtonFocus.canRequestFocus) {
                      _providersButtonFocus.requestFocus();
                    }
                  }
                : null,
            onUpEdge: _providerListOpen ? _focusFirstProviderRow : null,
            child: _cancelChipFace(),
          )
        : TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontFamily: 'Poppins',
              ),
            ),
          );

    if (!showListToggle) return cancelButton;

    final listButton = tvFocus
        ? shellFocusableTap(
            context: context,
            focusNode: _providersButtonFocus,
            onTap: _toggleProviderList,
            borderRadius: 24,
            scaleOnFocus: 1.0,
            showFocusBorder: true,
            onLeftEdge: () {
              if (_cancelFocus.canRequestFocus) {
                _cancelFocus.requestFocus();
              }
            },
            onUpEdge: _providerListOpen ? _focusFirstProviderRow : null,
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
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(12),
            ),
            icon: Icon(
              _providerListOpen ? Icons.layers : Icons.layers_outlined,
              size: 20,
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_providerListOpen) ...[
          _providerListPanel(),
          const SizedBox(height: 16),
          if (widget.onManualCheckProvider != null)
            Text(
              'TAP A SERVER TO CHECK MANUALLY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                fontFamily: 'Poppins',
              ),
            ),
          if (widget.onManualCheckProvider != null) const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            cancelButton,
            const SizedBox(width: 10),
            listButton,
          ],
        ),
      ],
    );
  }

  Widget _probeProgressFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.recheckBanner != null) ...[
          Text(
            widget.recheckBanner!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.amber.shade200.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.showReloadButton) ...[
          Text(
            widget.reloadHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onReload,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(widget.reloadLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          _message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontFamily: 'Poppins',
          ),
        ),
        if (_tryingProbe != null) ...[
          const SizedBox(height: 8),
          Text(
            _tryingProbe!.label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              fontFamily: 'Poppins',
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _probeProgress),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value > 0 ? value : null,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _probeSkipped > 0
              ? '$_probeChecked / $_probeTotal CHECKED  ·  $_probeReady UP  ·  $_probeSkipped SKIPPED ON TV'
              : '$_probeChecked / $_probeTotal CHECKED  ·  $_probeReady UP',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontFamily: 'Poppins',
          ),
        ),
        if (_probeSkipped > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _skippedProbeLabels.join(' · '),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ],
    );
  }

  String? get _logoImageUrl {
    final path = widget.movie.logoPath;
    if (path.isEmpty || path.toLowerCase().endsWith('.svg')) return null;
    if (path.startsWith('http')) return path;
    return TmdbApi.getImageUrl(path);
  }

  String _resolveBackdropUrl() {
    final path = widget.movie.backdropPath;
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return TmdbApi.getBackdropUrl(path);
  }

  Widget _titleFallback() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        widget.movie.title,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
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
                  errorWidget: (context, url, error) => Container(color: Colors.black),
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
                bottom: _logoBottomReserve,
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
                bottom: 48,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showingFailure)
                        ResolveFailurePanel(
                          failure: _failure!,
                          compact: true,
                        )
                      else if (_showProviderProbes)
                        _probeProgressFooter()
                      else ...[
                        if (widget.recheckBanner != null) ...[
                          Text(
                            widget.recheckBanner!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.amber.shade200.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (widget.showReloadButton) ...[
                          Text(
                            widget.reloadHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: widget.onReload,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(widget.reloadLabel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle!.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ],
                      if (!_showingFailure && widget.onCancel != null) ...[
                        SizedBox(height: _showProviderProbes ? 20 : 24),
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
              onDismiss: escapeAction,
              autofocusFirst: false,
              debugLabel: 'loading-overlay',
              child: overlay,
            ),
    );
  }
}
