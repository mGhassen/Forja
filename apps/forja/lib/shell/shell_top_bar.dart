import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';

class ShellTopBar extends StatefulWidget {
  const ShellTopBar({super.key});

  static const _scrollFadeDistance = 32.0;
  static const _gradientFadeExtent = 56.0;

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
    final topInset = MediaQuery.paddingOf(context).top;
    final chromeHeight = topInset + ShellTokens.shellTopBarHeight;
    final totalHeight = chromeHeight + ShellTopBar._gradientFadeExtent;

    return ValueListenableBuilder<double>(
      valueListenable: ShellBus.homeScrollOffset,
      builder: (context, scrollOffset, _) {
        final fadeIn = (scrollOffset / ShellTopBar._scrollFadeDistance).clamp(0.0, 1.0);
        final showOverlay = scrollOffset > 0;

        return SizedBox(
          height: showOverlay ? totalHeight : chromeHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showOverlay)
                IgnorePointer(
                  child: Opacity(
                    opacity: fadeIn,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: chromeHeight,
                          child: ClipRect(
                            child: AppTheme.isLightMode
                                ? ColoredBox(
                                    color: AppTheme.bgDark.withValues(alpha: 0.95),
                                  )
                                : BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                                    child: ColoredBox(
                                      color: AppTheme.bgDark.withValues(alpha: 0.72),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: chromeHeight,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.bgDark.withValues(alpha: 0.85),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildMenu(context),
              ),
            ],
          ),
        );
      },
    );
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
  bool _showLeftFade = false;
  bool _showRightFade = true;

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
    _updateEdgeFades();
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

    _updateEdgeFades();
  }

  void _updateEdgeFades() {
    if (!_scrollController.hasClients) return;
    final canScroll =
        _scrollController.position.maxScrollExtent > 0;
    final showLeft = canScroll;
    final showRight = canScroll;
    if (showLeft == _showLeftFade && showRight == _showRightFade) return;
    setState(() {
      _showLeftFade = showLeft;
      _showRightFade = showRight;
    });
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
    final fadeColor = AppTheme.bgDark;

    return ClipRect(
      child: SizedBox(
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
              return _ProviderFilterCard(
                key: ValueKey('watch-provider-${provider.id}-$index'),
                provider: provider,
                isActive: widget.selectedId == provider.id,
                onTap: () => widget.onProviderTap(provider.id),
              );
            },
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: ShellTokens.shellProviderEdgeFadeWidth,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showLeftFade ? 1 : 0,
                duration: ShellTokens.navSelectionAnimation,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0, 0.45, 1],
                      colors: [
                        fadeColor,
                        fadeColor.withValues(alpha: 0.85),
                        fadeColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: ShellTokens.shellProviderEdgeFadeWidth,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showRightFade ? 1 : 0,
                duration: ShellTokens.navSelectionAnimation,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      stops: const [0, 0.45, 1],
                      colors: [
                        fadeColor,
                        fadeColor.withValues(alpha: 0.85),
                        fadeColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ProviderFilterCard extends StatelessWidget {
  const _ProviderFilterCard({
    super.key,
    required this.provider,
    required this.isActive,
    required this.onTap,
  });

  final WatchProvider provider;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const width = ShellTokens.shellProviderCardWidth;
    const height = ShellTokens.shellProviderCardHeight;

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: ForjaInteractive(
          onTap: onTap,
          hoverScale: ShellTokens.shellProviderHoverScale,
          pressScale: 0.98,
          builder: (hover, _) {
            final elevated = hover || isActive;
            return AnimatedContainer(
              duration: ShellTokens.navSelectionAnimation,
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius:
                    BorderRadius.circular(ShellTokens.shellProviderCardRadius),
                border: Border.all(
                  color: elevated
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  width: elevated ? 2 : 1,
                ),
                boxShadow: hover
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (provider.logoPath.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          provider.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: provider.logoCardUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Center(
                        child: Text(
                          provider.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (isActive)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
