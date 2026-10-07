import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Floating Next Episode chip.
///
/// With [countdown], a 10-second ring runs, then [onCountdownComplete] fires.
/// The X inside the chip calls [onCancel]. The ring holds while
/// [countdownPaused], while hovered, and while the user has focus on it.
/// D-pad → from the chip lands on the X; ← goes back.
class PlayerNextEpisodeChip extends StatefulWidget {
  const PlayerNextEpisodeChip({
    super.key,
    required this.onPressed,
    this.countdown = false,
    this.countdownPaused = false,
    this.onCountdownComplete,
    this.onCancel,
    this.focusNode,
    this.tvFocusable = false,
    this.onArrowUp,
    this.onArrowDown,
    this.pauseOnFocus = true,
  });

  static const Duration countdownDuration = Duration(seconds: 10);

  final VoidCallback onPressed;
  final bool countdown;
  final bool countdownPaused;
  final VoidCallback? onCountdownComplete;
  final VoidCallback? onCancel;
  final FocusNode? focusNode;
  final bool tvFocusable;
  /// D-pad ↑ / ↓ from the chip. Return true when focus moved.
  final bool Function()? onArrowUp;
  final bool Function()? onArrowDown;
  /// False when the host moved focus here on its own (TV chip appearing) —
  /// that focus must not hold the countdown until the user presses a key.
  final bool pauseOnFocus;

  @override
  State<PlayerNextEpisodeChip> createState() => _PlayerNextEpisodeChipState();
}

class _PlayerNextEpisodeChipState extends State<PlayerNextEpisodeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: PlayerNextEpisodeChip.countdownDuration,
  )..addStatusListener(_onRingStatus);
  final FocusNode _cancelNode = FocusNode(debugLabel: 'player-up-next-cancel');
  FocusNode? _ownedMainNode;
  final ValueNotifier<bool> _mainHovered = ValueNotifier(false);
  final ValueNotifier<bool> _cancelHovered = ValueNotifier(false);
  bool _mainFocused = false;
  bool _cancelFocused = false;
  /// User pressed a key on the chip since the countdown started.
  bool _userNavigated = false;

  /// Hover or user focus holds the countdown.
  bool get _heldByUser =>
      _mainHovered.value ||
      _cancelHovered.value ||
      _cancelFocused ||
      (_mainFocused && (widget.pauseOnFocus || _userNavigated));

  FocusNode get _mainNode =>
      widget.focusNode ??
      (_ownedMainNode ??= FocusNode(debugLabel: 'player-up-next-main'));

  bool get _showCancel => widget.countdown && widget.onCancel != null;

  @override
  void initState() {
    super.initState();
    _mainHovered.addListener(_onHoldChanged);
    _cancelHovered.addListener(_onHoldChanged);
    _syncRing(restart: widget.countdown);
  }

  void _onHoldChanged() => _syncRing(restart: false);

  @override
  void didUpdateWidget(covariant PlayerNextEpisodeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countdown != widget.countdown ||
        oldWidget.countdownPaused != widget.countdownPaused ||
        oldWidget.pauseOnFocus != widget.pauseOnFocus) {
      _syncRing(restart: widget.countdown && !oldWidget.countdown);
    }
    if (!_showCancel && _cancelNode.hasFocus && _mainNode.canRequestFocus) {
      _mainNode.requestFocus();
    }
  }

  void _syncRing({required bool restart}) {
    if (!widget.countdown) {
      _ring
        ..stop()
        ..value = 0;
      return;
    }
    if (restart) {
      _ring.value = 0;
      _userNavigated = false;
    }
    if (widget.countdownPaused || _heldByUser) {
      _ring.stop();
    } else if (!_ring.isAnimating) {
      _ring.forward();
    }
  }

  void _onRingStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !widget.countdown) return;
    widget.onCountdownComplete?.call();
  }

  void _cancel() {
    if (_cancelNode.hasFocus && _mainNode.canRequestFocus) {
      _mainNode.requestFocus();
    }
    widget.onCancel?.call();
  }

  KeyEventResult _onVertical(KeyEvent event) {
    final key = event.logicalKey;
    final move = key == LogicalKeyboardKey.arrowUp
        ? widget.onArrowUp
        : key == LogicalKeyboardKey.arrowDown
            ? widget.onArrowDown
            : null;
    if (move != null && move()) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  void _noteUserKey() {
    if (_userNavigated) return;
    _userNavigated = true;
    _syncRing(restart: false);
  }

  KeyEventResult _onMainKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    _noteUserKey();
    if (_onVertical(event) == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight && _showCancel) {
      _cancelNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCancelKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    _noteUserKey();
    if (_onVertical(event) == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _mainNode.requestFocus();
      return KeyEventResult.handled;
    }
    // Last stop on the right — never wander into hidden chrome.
    if (key == LogicalKeyboardKey.arrowRight) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _ring.dispose();
    _cancelNode.dispose();
    _ownedMainNode?.dispose();
    _mainHovered.dispose();
    _cancelHovered.dispose();
    super.dispose();
  }

  bool _tvFocused(bool focused) => playerChromeTvFocused(
    context,
    tvFocusable: widget.tvFocusable,
    focused: focused,
  );

  Color _fill({required bool hovered, required bool focused}) {
    if (_tvFocused(focused)) {
      return ForjaShellColors.brandGreen.withValues(alpha: 0.14);
    }
    final highlight = playerChromeFocusActive(
      context,
      tvFocusable: widget.tvFocusable,
      hovered: hovered,
      focused: focused,
    );
    return highlight ? ForjaShellColors.inkHover : Colors.transparent;
  }

  Color _fg(bool focused) =>
      _tvFocused(focused) ? ForjaShellColors.brandGreen : Colors.white;

  Widget _countdownRing(Color fg) {
    final total = PlayerNextEpisodeChip.countdownDuration.inSeconds;
    return AnimatedBuilder(
      animation: _ring,
      builder: (context, _) {
        final left = (total * (1 - _ring.value)).ceil().clamp(1, total);
        return SizedBox(
          width: PlayerFloatingChipMetrics.ringSize,
          height: PlayerFloatingChipMetrics.ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1 - _ring.value,
                strokeWidth: 2,
                color: fg,
                backgroundColor: ForjaShellColors.borderSubtle,
              ),
              Text(
                '$left',
                style: TextStyle(
                  color: fg,
                  fontSize: PlayerFloatingChipMetrics.ringFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mainBody(bool hovered) {
    final fg = _fg(_mainFocused);
    return ColoredBox(
      color: _fill(hovered: hovered, focused: _mainFocused),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: playerChromeScale(
            context,
            PlayerFloatingChipMetrics.padH,
          ),
          vertical: playerChromeScale(context, PlayerFloatingChipMetrics.padV),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.countdown) ...[
              _countdownRing(fg),
              const SizedBox(width: 10),
            ],
            Text(
              'Next Episode',
              style: TextStyle(
                color: fg,
                fontSize: playerChromeTypeSize(
                  context,
                  PlayerFloatingChipMetrics.fontSize,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: fg,
              size: ShellPaintScope.iconOf(
                context,
                PlayerFloatingChipMetrics.iconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cancelBody(bool hovered) {
    final fg = _fg(_cancelFocused);
    return ColoredBox(
      color: _fill(hovered: hovered, focused: _cancelFocused),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: playerChromeScale(
            context,
            PlayerFloatingChipMetrics.cancelPadH,
          ),
          vertical: playerChromeScale(context, PlayerFloatingChipMetrics.padV),
        ),
        child: Icon(
          Icons.close_rounded,
          color: fg,
          size: ShellPaintScope.iconOf(
            context,
            PlayerFloatingChipMetrics.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _part({
    required ValueNotifier<bool> hovered,
    required Widget Function(bool hovered) body,
    required VoidCallback onTap,
    required FocusNode focusNode,
    required FocusOnKeyEventCallback onKey,
    required ValueChanged<bool> onFocusChange,
  }) {
    final painted = ListenableBuilder(
      listenable: hovered,
      builder: (context, _) => body(hovered.value),
    );
    if (widget.tvFocusable) {
      return FocusableControl(
        focusNode: focusNode,
        onTap: onTap,
        onKeyEvent: onKey,
        borderRadius: 0,
        scaleOnFocus: 1.0,
        onFocusChange: onFocusChange,
        child: painted,
      );
    }
    return MouseRegion(
      onEnter: (_) => hovered.value = true,
      onExit: (_) => hovered.value = false,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: painted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anyTvFocus = _tvFocused(_mainFocused) || _tvFocused(_cancelFocused);
    return Focus(
      debugLabel: kPlayerFloatingChipFocusLabel,
      canRequestFocus: false,
      skipTraversal: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(PlayerFloatingChipMetrics.radius),
          border: Border.all(
            color: anyTvFocus
                ? ForjaShellColors.brandGreen
                : ForjaShellColors.borderSubtle,
            width: anyTvFocus ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PlayerFloatingChipMetrics.radius),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _part(
                hovered: _mainHovered,
                body: _mainBody,
                onTap: widget.onPressed,
                focusNode: _mainNode,
                onKey: _onMainKey,
                onFocusChange: (f) {
                  if (!mounted) return;
                  setState(() => _mainFocused = f);
                  _syncRing(restart: false);
                },
              ),
              if (_showCancel) ...[
                Container(
                  width: 1,
                  height: PlayerFloatingChipMetrics.ringSize,
                  color: ForjaShellColors.borderSubtle,
                ),
                _part(
                  hovered: _cancelHovered,
                  body: _cancelBody,
                  onTap: _cancel,
                  focusNode: _cancelNode,
                  onKey: _onCancelKey,
                  onFocusChange: (f) {
                    if (!mounted) return;
                    setState(() => _cancelFocused = f);
                    _syncRing(restart: false);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
