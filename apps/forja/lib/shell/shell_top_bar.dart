import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:rust/rust.dart';

/// TMDB watch-provider strip for desktop shell.
///
/// Hidden on Home for v1.0 - mount via [kShowShellProviderMenuOnHome] or embed
/// on Search (and other tabs) when that UX ships.
const bool kShowShellProviderMenuOnHome = false;

class ShellTopBar extends StatefulWidget {
  const ShellTopBar({super.key});

  @override
  State<ShellTopBar> createState() => _ShellTopBarState();
}

class _ShellTopBarState extends State<ShellTopBar> {
  final TmdbApi _api = TmdbApi();
  late Future<List<WatchProvider>> _providersFuture;

  @override
  void initState() {
    super.initState();
    _providersFuture = _api.getTopWatchProviders();
  }

  void _onProviderTap(int providerId) {
    final current = ShellBus.selectedWatchProviderId.value;
    ShellBus.selectedWatchProviderId.value =
        current == providerId ? null : providerId;
    ShellBus.requestTab.value = 'home';
  }

  @override
  Widget build(BuildContext context) {
    return _buildMenu(context);
  }

  Widget _buildMenu(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        width: double.infinity,
        height: ShellTokens.shellTopBarHeight,
        child: Padding(
          padding: const EdgeInsets.only(
            left: ShellTokens.bodyHorizontalPadding,
            right: ShellTokens.shellProviderRowRightInset,
          ),
          child: FutureBuilder<List<WatchProvider>>(
            future: _providersFuture,
            builder: (context, snapshot) {
              final providers = snapshot.data ?? TmdbApi.fallbackWatchProviders;
              return ValueListenableBuilder<int?>(
                valueListenable: ShellBus.selectedWatchProviderId,
                builder: (context, selectedId, _) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: _ProviderFilterStrip(
                      providers: providers,
                      selectedId: selectedId,
                      onProviderTap: _onProviderTap,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProviderFilterStrip extends StatefulWidget {
  const _ProviderFilterStrip({
    required this.providers,
    required this.selectedId,
    required this.onProviderTap,
  });

  final List<WatchProvider> providers;
  final int? selectedId;
  final ValueChanged<int> onProviderTap;

  @override
  State<_ProviderFilterStrip> createState() => _ProviderFilterStripState();
}

class _ProviderFilterStripState extends State<_ProviderFilterStrip> {
  static const int _loopCopies = 3;

  final ScrollController _scrollController = ScrollController();
  bool _isLoopJumping = false;

  static const double _itemStride =
      ShellTokens.shellProviderCardWidth + ShellTokens.shellProviderCardGap;

  int get _providerCount => widget.providers.length;

  int get _loopedItemCount => _providerCount * _loopCopies;

  double get _loopExtent => _providerCount * _itemStride;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToMiddleLoop());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToMiddleLoop() {
    if (!_scrollController.hasClients || _providerCount == 0) return;
    _isLoopJumping = true;
    final peek =
        ShellTokens.shellProviderCardWidth * ShellTokens.shellProviderEdgePeekFraction;
    _scrollController.jumpTo(_loopExtent - peek);
    _isLoopJumping = false;
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_isLoopJumping || !_scrollController.hasClients || _providerCount == 0) {
      return;
    }

    final offset = _scrollController.offset;
    if (offset < _loopExtent * 0.5) {
      _isLoopJumping = true;
      _scrollController.jumpTo(offset + _loopExtent);
      _isLoopJumping = false;
    } else if (offset > _loopExtent * 2.5) {
      _isLoopJumping = true;
      _scrollController.jumpTo(offset - _loopExtent);
      _isLoopJumping = false;
    }

    setState(() {});
  }

  /// 0 = far from center, 1 = centered in the viewport (drives default scale).
  double _centerFocusForIndex(int index) {
    if (!_scrollController.hasClients) return 0;
    final viewport = _scrollController.position.viewportDimension;
    final cardCenter =
        index * _itemStride + ShellTokens.shellProviderCardWidth / 2;
    final viewCenter = _scrollController.offset + viewport / 2;
    final distance = (cardCenter - viewCenter).abs();
    final threshold =
        _itemStride * ShellTokens.shellProviderCenterFocusThreshold;
    return (1 - distance / threshold).clamp(0.0, 1.0);
  }

  int? _centeredListIndex() {
    if (!_scrollController.hasClients || _loopedItemCount == 0) return null;
    var bestIndex = 0;
    var bestFocus = -1.0;
    for (var i = 0; i < _loopedItemCount; i++) {
      final focus = _centerFocusForIndex(i);
      if (focus > bestFocus) {
        bestFocus = focus;
        bestIndex = i;
      }
    }
    return bestFocus > 0.35 ? bestIndex : null;
  }

  @override
  void didUpdateWidget(covariant _ProviderFilterStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.providers.length != oldWidget.providers.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToMiddleLoop());
    }
    if (widget.selectedId != oldWidget.selectedId && widget.selectedId != null) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final selectedId = widget.selectedId;
    if (selectedId == null || _providerCount == 0) return;
    final index = widget.providers.indexWhere((p) => p.id == selectedId);
    if (index < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final viewport = _scrollController.position.viewportDimension;
      final loopIndex = _providerCount + index;
      final target = (loopIndex * _itemStride) - (viewport - _itemStride) / 2;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: ShellTokens.navSelectionAnimation,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final centeredIndex = _centeredListIndex();

    return SizedBox(
        width: ShellTokens.shellProviderRowViewportWidth,
        height: ShellTokens.shellProviderStripHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              clipBehavior: Clip.none,
              itemCount: _loopedItemCount,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: ShellTokens.shellProviderCardGap),
              itemBuilder: (context, index) {
                final provider = widget.providers[index % _providerCount];
                final isCentered = centeredIndex == index;
                final centerFocus =
                    isCentered ? 0.0 : _centerFocusForIndex(index);
                return Visibility(
                  visible: !isCentered,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: _ProviderFilterCard(
                    key: ValueKey('watch-provider-${provider.id}-$index'),
                    provider: provider,
                    isActive: widget.selectedId == provider.id,
                    isCenterFocused: false,
                    centerFocus: centerFocus,
                    onTap: () => widget.onProviderTap(provider.id),
                  ),
                );
              },
            ),
            if (centeredIndex != null && _scrollController.hasClients)
              Positioned(
                left: centeredIndex * _itemStride - _scrollController.offset,
                width: ShellTokens.shellProviderCardWidth,
                height: ShellTokens.shellProviderStripHeight,
                child: _ProviderFilterCard(
                  key: ValueKey(
                    'watch-provider-overlay-${widget.providers[centeredIndex % _providerCount].id}-$centeredIndex',
                  ),
                  provider: widget.providers[centeredIndex % _providerCount],
                  isActive: widget.selectedId ==
                      widget.providers[centeredIndex % _providerCount].id,
                  isCenterFocused: true,
                  centerFocus: 1,
                  onTap: () => widget.onProviderTap(
                    widget.providers[centeredIndex % _providerCount].id,
                  ),
                ),
              ),
          ],
        ),
    );
  }
}

class _ProviderFilterCard extends StatelessWidget {
  const _ProviderFilterCard({
    super.key,
    required this.provider,
    required this.isActive,
    required this.isCenterFocused,
    required this.centerFocus,
    required this.onTap,
  });

  final WatchProvider provider;
  final bool isActive;
  final bool isCenterFocused;
  final double centerFocus;
  final VoidCallback onTap;

  double get _targetScale {
    final centerScale = 1 +
        (ShellTokens.shellProviderHoverScale - 1) * centerFocus;
    return centerScale;
  }

  @override
  Widget build(BuildContext context) {
    const width = ShellTokens.shellProviderCardWidth;
    const height = ShellTokens.shellProviderCardHeight;
    final showElevated = isCenterFocused || isActive;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ForjaInteractive(
            onTap: onTap,
            hoverScale: 1,
            pressScale: 1,
            builder: (hover, _) {
              final scale = hover
                  ? ShellTokens.shellProviderHoverScale
                  : _targetScale;
              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: ShellTokens.navSelectionAnimation,
                  width: width,
                  height: height,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(
                      ShellTokens.shellProviderCardRadius,
                    ),
                    border: Border.all(
                      color: showElevated || hover
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.1),
                      width: showElevated || hover ? 2 : 1,
                    ),
                    boxShadow: hover || isCenterFocused
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                    image: provider.logoPath.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                              provider.logoCardUrl,
                            ),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          )
                        : null,
                  ),
                  child: provider.logoPath.isEmpty
                      ? Center(
                          child: Text(
                            provider.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
          if (isActive)
            Positioned(
              top: 6,
              right: 6,
              child: const _ProviderSelectedMark(),
            ),
        ],
      ),
    );
  }
}

/// Thin line check - always visible when provider filter is active.
class _ProviderSelectedMark extends StatelessWidget {
  const _ProviderSelectedMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 4,
          ),
        ],
      ),
      child: CustomPaint(
        size: const Size(16, 12),
        painter: _LineCheckPainter(color: Colors.white),
      ),
    );
  }
}

class _LineCheckPainter extends CustomPainter {
  _LineCheckPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.52)
      ..lineTo(size.width * 0.38, size.height * 0.82)
      ..lineTo(size.width * 0.9, size.height * 0.18);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}
