import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/watch_provider_chrome.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Toggle TMDB watch-provider filter; clears when [providerId] is already selected.
void toggleHomeWatchProvider(int providerId) {
  final current = ShellBus.selectedWatchProviderId.value;
  ShellBus.selectedWatchProviderId.value =
      current == providerId ? null : providerId;
}

/// Local SVG logo on a contrasting tile (inset / optional white recolor).
class WatchProviderLogoMark extends StatelessWidget {
  const WatchProviderLogoMark({
    super.key,
    required this.chrome,
    required this.width,
    required this.height,
    this.inset,
    this.borderRadius,
    this.showTile = true,
  });

  final WatchProviderChrome chrome;
  final double width;
  final double height;
  final double? inset;
  final BorderRadius? borderRadius;
  final bool showTile;

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ??
        BorderRadius.circular(ShellTokens.shellProviderCardRadius);
    final pad = (width < height ? width : height) * (inset ?? chrome.inset);
    Widget logo = SvgPicture.asset(
      chrome.assetPath,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      allowDrawingOutsideViewBox: false,
      colorFilter: chrome.forceWhiteLogo
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null,
    );
    logo = Padding(padding: EdgeInsets.all(pad), child: logo);
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: showTile ? chrome.tileColor : Colors.transparent,
        child: SizedBox(width: width, height: height, child: logo),
      ),
    );
  }
}

/// Selected provider mark before Films — rectangle SVG logo tile.
class HomeSelectedWatchProviderLogo extends StatelessWidget {
  const HomeSelectedWatchProviderLogo({
    super.key,
    this.width = ShellTokens.shellProviderTopBarIconWidth,
    this.height = ShellTokens.shellProviderTopBarIconHeight,
    this.tvFocus = false,
    this.focusNode,
    this.listIndex,
    this.onDownEdge,
  });

  final double width;
  final double height;
  final bool tvFocus;
  final FocusNode? focusNode;
  final int? listIndex;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: ShellBus.selectedWatchProviderId,
      builder: (context, selectedId, _) {
        if (selectedId == null) return const SizedBox.shrink();
        final chrome = watchProviderChromeById(selectedId);
        if (chrome == null) return const SizedBox.shrink();
        if (tvFocus) {
          return _TvSelectedWatchProviderLogo(
            chrome: chrome,
            width: width,
            height: height,
            focusNode: focusNode,
            listIndex: listIndex,
            onDownEdge: onDownEdge,
          );
        }
        return ForjaInteractive(
          onTap: ShellBus.onTopProviderLogoTap,
          hoverScale: 1.04,
          pressScale: 0.96,
          builder: (hover, _) {
            return MouseRegion(
              onEnter: (_) => ShellBus.cancelHomeProviderMenuHide(),
              onExit: (_) => ShellBus.scheduleHomeProviderMenuHide(),
              child: _ProviderTopMark(
                chrome: chrome,
                width: width,
                height: height,
                showRing: hover,
              ),
            );
          },
        );
      },
    );
  }
}

class _TvSelectedWatchProviderLogo extends StatefulWidget {
  const _TvSelectedWatchProviderLogo({
    required this.chrome,
    required this.width,
    required this.height,
    this.focusNode,
    this.listIndex,
    this.onDownEdge,
  });

  final WatchProviderChrome chrome;
  final double width;
  final double height;
  final FocusNode? focusNode;
  final int? listIndex;
  final VoidCallback? onDownEdge;

  @override
  State<_TvSelectedWatchProviderLogo> createState() =>
      _TvSelectedWatchProviderLogoState();
}

class _TvSelectedWatchProviderLogoState
    extends State<_TvSelectedWatchProviderLogo> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      onTap: () {
        // Open rail + land focus on the selected provider (don't clear filter).
        ShellBus.showHomeProviderMenu();
        ShellTvFocus.scheduleFocusHomeProviderById(widget.chrome.id);
      },
      borderRadius: 8,
      scaleOnFocus: ShellTokens.focusActiveScale,
      listIndex: widget.listIndex,
      tvTabId: 'home',
      tvRowId: 'top-bar',
      tvZone: ShellTvZone.topBar,
      tvItemIndex: widget.listIndex,
      focusNode: widget.focusNode,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: _ProviderTopMark(
        chrome: widget.chrome,
        width: widget.width,
        height: widget.height,
        showRing: _focused,
      ),
    );
  }
}

class _ProviderTopMark extends StatelessWidget {
  const _ProviderTopMark({
    required this.chrome,
    required this.width,
    required this.height,
    required this.showRing,
  });

  final WatchProviderChrome chrome;
  final double width;
  final double height;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    const ring = 1.5;
    return TapRegion(
      groupId: ShellBus.homeProviderMenuTapGroup,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: showRing ? Colors.white : Colors.transparent,
              width: ring,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ring),
            child: WatchProviderLogoMark(
              chrome: chrome,
              width: width - ring * 2,
              height: height - ring * 2,
              inset: 0.14,
              borderRadius: BorderRadius.circular(6.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating service-provider panel — same paint as nav rail, beside it.
class HomeWatchProviderRail extends StatelessWidget {
  const HomeWatchProviderRail({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.homeProviderMenuVisible,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();
        return ValueListenableBuilder<int?>(
          valueListenable: ShellBus.selectedWatchProviderId,
          builder: (context, selectedId, _) {
            return TapRegion(
              groupId: ShellBus.homeProviderMenuTapGroup,
              onTapOutside: (_) => ShellBus.hideHomeProviderMenu(),
              child: MouseRegion(
                onEnter: (_) => ShellBus.cancelHomeProviderMenuHide(),
                onExit: (_) => ShellBus.scheduleHomeProviderMenuHide(),
                child: _ProviderRailPanel(
                  selectedId: selectedId,
                  onProviderTap: toggleHomeWatchProvider,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProviderRailPanel extends StatefulWidget {
  const _ProviderRailPanel({
    required this.selectedId,
    required this.onProviderTap,
  });

  final int? selectedId;
  final ValueChanged<int> onProviderTap;

  @override
  State<_ProviderRailPanel> createState() => _ProviderRailPanelState();
}

class _ProviderRailPanelState extends State<_ProviderRailPanel> {
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List<FocusNode>.generate(
      kHomeWatchProviderChrome.length,
      (i) => FocusNode(debugLabel: 'home-provider-$i'),
    );
    if (_focusNodes.isNotEmpty) {
      ShellTvFocus.homeProviderRailFirst = _focusNodes.first;
    }
    for (var i = 0; i < kHomeWatchProviderChrome.length; i++) {
      ShellTvFocus.homeProviderRailById[kHomeWatchProviderChrome[i].id] =
          _focusNodes[i];
    }
  }

  @override
  void dispose() {
    if (_focusNodes.isNotEmpty &&
        identical(ShellTvFocus.homeProviderRailFirst, _focusNodes.first)) {
      ShellTvFocus.homeProviderRailFirst = null;
    }
    for (final chrome in kHomeWatchProviderChrome) {
      final node = ShellTvFocus.homeProviderRailById[chrome.id];
      if (node != null && _focusNodes.contains(node)) {
        ShellTvFocus.homeProviderRailById.remove(chrome.id);
      }
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _focusTile(int index) {
    if (index < 0 || index >= _focusNodes.length) return;
    final node = _focusNodes[index];
    if (!node.canRequestFocus) return;
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = node.context;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.88;
        return Material(
          color: Colors.transparent,
          elevation: 0,
          child: Container(
            width: ShellTokens.shellProviderRailWidth,
            constraints: BoxConstraints(maxHeight: maxH),
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(
                ShellTokens.shellProviderRailRadius,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  vertical: ShellTokens.shellProviderRailPadV,
                  horizontal: ShellTokens.shellProviderRailPadH,
                ),
                itemCount: kHomeWatchProviderChrome.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: ShellTokens.shellProviderRailGap),
                itemBuilder: (context, i) {
                  return FocusTraversalOrder(
                    order: NumericFocusOrder(i.toDouble()),
                    child: _ProviderRailTile(
                      chrome: kHomeWatchProviderChrome[i],
                      index: i,
                      focusNodes: _focusNodes,
                      selected: widget.selectedId ==
                          kHomeWatchProviderChrome[i].id,
                      onTap: () => widget
                          .onProviderTap(kHomeWatchProviderChrome[i].id),
                      onFocusNeighbor: _focusTile,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProviderRailTile extends StatelessWidget {
  const _ProviderRailTile({
    required this.chrome,
    required this.index,
    required this.focusNodes,
    required this.selected,
    required this.onTap,
    required this.onFocusNeighbor,
  });

  final WatchProviderChrome chrome;
  final int index;
  final List<FocusNode> focusNodes;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<int> onFocusNeighbor;

  FocusNode get focusNode => focusNodes[index];

  @override
  Widget build(BuildContext context) {
    const w = ShellTokens.shellProviderTileWidth;
    const h = ShellTokens.shellProviderTileHeight;
    final radius = BorderRadius.circular(ShellTokens.shellProviderCardRadius);
    return ForjaInteractive(
      focusNode: focusNode,
      onTap: onTap,
      hoverScale: 1.06,
      pressScale: 0.96,
      onKeyEvent: (node, event) {
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        final key = event.logicalKey;
        // ←/→ dismiss panel. ↑/↓ stay inside (never home rows).
        if (key == LogicalKeyboardKey.arrowLeft) {
          ShellBus.hideHomeProviderMenu();
          final home = ShellTvFocus.navNode('home');
          if (home != null && home.canRequestFocus) {
            home.requestFocus();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          ShellBus.hideHomeProviderMenu();
          ShellTvFocusCoordinator.restoreTabFocusAfterNav('home');
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          if (index > 0) onFocusNeighbor(index - 1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          if (index < focusNodes.length - 1) onFocusNeighbor(index + 1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      builder: (active, _) {
        final showRing = selected || active;
        const ring = 2.0;
        return Tooltip(
          message: chrome.name,
          waitDuration: const Duration(milliseconds: 400),
          child: AnimatedContainer(
            duration: ShellTokens.navSelectionAnimation,
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                // Fixed width always — logo inset below so straight edges of
                // the ring aren't covered (looked like corner brackets).
                color: showRing ? Colors.white : Colors.transparent,
                width: ring,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(ring),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WatchProviderLogoMark(
                    chrome: chrome,
                    width: w - ring * 2,
                    height: h - ring * 2,
                    borderRadius: BorderRadius.circular(
                      ShellTokens.shellProviderCardRadius - 1,
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      top: 1,
                      right: 1,
                      child: _ProviderSelectedMark(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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
        size: const Size(12, 10),
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

/// Legacy alias — vertical rail is [HomeWatchProviderRail].
@Deprecated('Use HomeWatchProviderRail')
class HomeWatchProviderStrip extends StatelessWidget {
  const HomeWatchProviderStrip({super.key});

  @override
  Widget build(BuildContext context) => const HomeWatchProviderRail();
}

/// Standalone host kept for tests.
class ShellTopBar extends StatelessWidget {
  const ShellTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: ShellTokens.shellProviderRailWidth,
      child: HomeWatchProviderRail(),
    );
  }
}
