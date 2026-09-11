import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/foundation/lib/pack_assets.dart';
import 'package:forja/shared/foundation/components/chrome/vertical_filters.dart';
import 'package:forja/shared/foundation/primitives/chrome/shell_focusable_tap.dart';
import 'package:forja/shared/foundation/primitives/controls/forja_buttons.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/foundation/tv/shell_tv_focus.dart';
import 'package:forja_foundation/widgets/logo_menu_rail.dart';

/// Pack-owned logo on a contrasting tile.
class VerticalFilterLogoMark extends StatefulWidget {
  const VerticalFilterLogoMark({
    super.key,
    required this.option,
    required this.packSourceUrl,
    required this.width,
    required this.height,
    this.inset,
    this.borderRadius,
    this.showTile = true,
  });

  final VerticalFilterOption option;
  final String packSourceUrl;
  final double width;
  final double height;
  final double? inset;
  final BorderRadius? borderRadius;
  final bool showTile;

  @override
  State<VerticalFilterLogoMark> createState() => _VerticalFilterLogoMarkState();
}

class _VerticalFilterLogoMarkState extends State<VerticalFilterLogoMark> {
  late Future<String?> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = _load();
  }

  @override
  void didUpdateWidget(covariant VerticalFilterLogoMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.option.logo != widget.option.logo ||
        oldWidget.packSourceUrl != widget.packSourceUrl) {
      _resolved = _load();
    }
  }

  Future<String?> _load() async {
    final rel = widget.option.logo.trim();
    final base = widget.packSourceUrl.trim();
    if (rel.isEmpty) return null;
    if (base.isNotEmpty && PackAssets.isPackRelativeAsset(rel)) {
      await PluginRegistry.instance.ensureRemotePackRelativeFile(
        sourceUrl: base,
        relative: rel,
      );
    }
    return PackAssets.resolvePackAssetDisplay(
      packSourceUrl: base.isEmpty ? null : base,
      relative: rel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ??
        BorderRadius.circular(ShellTokens.shellProviderCardRadius);
    final pad = (widget.width < widget.height ? widget.width : widget.height) *
        (widget.inset ?? widget.option.inset);
    return FutureBuilder<String?>(
      future: _resolved,
      builder: (context, snap) {
        final url = snap.data?.trim() ?? '';
        Widget logo = url.isEmpty
            ? const SizedBox.shrink()
            : _PackSvg(url: url, fit: BoxFit.contain);
        if (widget.option.forceWhiteLogo) {
          logo = ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: logo,
          );
        }
        logo = Padding(padding: EdgeInsets.all(pad), child: logo);
        return ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: widget.showTile ? widget.option.tileColor : Colors.transparent,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: logo,
            ),
          ),
        );
      },
    );
  }
}

class _PackSvg extends StatefulWidget {
  const _PackSvg({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  State<_PackSvg> createState() => _PackSvgState();
}

class _PackSvgState extends State<_PackSvg> with WidgetsBindingObserver {
  int _networkEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final url = widget.url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;
    setState(() => _networkEpoch++);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url.isEmpty) return const SizedBox.shrink();
    if (url.startsWith('assets/')) {
      return SvgPicture.asset(
        url,
        fit: widget.fit,
        alignment: Alignment.center,
        allowDrawingOutsideViewBox: false,
      );
    }
    final file = PackAssets.asLocalFile(url);
    if (file != null) {
      return SvgPicture.file(
        file,
        fit: widget.fit,
        alignment: Alignment.center,
        allowDrawingOutsideViewBox: false,
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return SvgPicture.network(
        url,
        key: ValueKey('vf-svg-$url-$_networkEpoch'),
        fit: widget.fit,
        alignment: Alignment.center,
        allowDrawingOutsideViewBox: false,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Selected filter mark before hub top-bar Search.
class VerticalFilterTopBarLogo extends StatelessWidget {
  const VerticalFilterTopBarLogo({
    super.key,
    required this.tabId,
    this.width = ShellTokens.shellProviderTopBarIconWidth,
    this.height = ShellTokens.shellProviderTopBarIconHeight,
    this.tvFocus = false,
    this.focusNode,
    this.listIndex,
    this.onDownEdge,
  });

  final String tabId;
  final double width;
  final double height;
  final bool tvFocus;
  final FocusNode? focusNode;
  final int? listIndex;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: VerticalFiltersRegistry.selectedIdFor(tabId),
      builder: (context, selectedId, _) {
        final spec = VerticalFiltersRegistry.specFor(tabId);
        final option = spec?.optionById(selectedId);
        if (spec == null || option == null) return const SizedBox.shrink();
        if (tvFocus) {
          return _TvSelectedFilterLogo(
            tabId: tabId,
            option: option,
            packSourceUrl: spec.packSourceUrl,
            width: width,
            height: height,
            focusNode: focusNode,
            listIndex: listIndex,
            onDownEdge: onDownEdge,
          );
        }
        return ForjaInteractive(
          onTap: () => VerticalFiltersRegistry.onTopLogoTap(tabId),
          builder: (_, _) => VerticalFilterLogoMark(
            option: option,
            packSourceUrl: spec.packSourceUrl,
            width: width,
            height: height,
            inset: 0.14,
            borderRadius: BorderRadius.circular(6.5),
          ),
        );
      },
    );
  }
}

class _TvSelectedFilterLogo extends StatelessWidget {
  const _TvSelectedFilterLogo({
    required this.tabId,
    required this.option,
    required this.packSourceUrl,
    required this.width,
    required this.height,
    this.focusNode,
    this.listIndex,
    this.onDownEdge,
  });

  final String tabId;
  final VerticalFilterOption option;
  final String packSourceUrl;
  final double width;
  final double height;
  final FocusNode? focusNode;
  final int? listIndex;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      focusNode: focusNode,
      listIndex: listIndex,
      onTap: () => VerticalFiltersRegistry.onTopLogoTap(tabId),
      onDownEdge: onDownEdge,
      onRightEdge: () {
        VerticalFiltersRegistry.showMenu(tabId);
        ShellTvFocus.scheduleFocusVerticalFilterById(tabId, option.id);
      },
      child: VerticalFilterLogoMark(
        option: option,
        packSourceUrl: packSourceUrl,
        width: width,
        height: height,
        inset: 0.14,
        borderRadius: BorderRadius.circular(6.5),
      ),
    );
  }
}

/// Floating vertical filter panel beside the nav rail.
///
/// DS target: [LogoMenuRail] + [VerticalMenu] from `package:forja_foundation`
/// (see [VerticalFiltersSpec.toLogoMenuItems]). This host widget stays until
/// pack SVG tiles, [PackAssets], tile colors, and TV focus graph can be
/// expressed as props-only leading widgets on [LogoMenuRail].
class VerticalFiltersRail extends StatelessWidget {
  const VerticalFiltersRail({super.key, required this.tabId});

  final String tabId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: VerticalFiltersRegistry.revision,
      builder: (context, _, _) {
        final spec = VerticalFiltersRegistry.specFor(tabId);
        if (spec == null || spec.options.isEmpty) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: VerticalFiltersRegistry.menuVisibleFor(tabId),
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            return ValueListenableBuilder<String?>(
              valueListenable:
                  VerticalFiltersRegistry.selectedIdFor(tabId),
              builder: (context, selectedId, _) {
                return TapRegion(
                  groupId: VerticalFiltersRegistry.menuTapGroup,
                  onTapOutside: (_) =>
                      VerticalFiltersRegistry.hideMenu(tabId),
                  child: MouseRegion(
                    onEnter: (_) =>
                        VerticalFiltersRegistry.cancelMenuHide(tabId),
                    onExit: (_) =>
                        VerticalFiltersRegistry.scheduleMenuHide(tabId),
                    child: _VerticalFiltersPanel(
                      tabId: tabId,
                      spec: spec,
                      selectedId: selectedId,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VerticalFiltersPanel extends StatefulWidget {
  const _VerticalFiltersPanel({
    required this.tabId,
    required this.spec,
    required this.selectedId,
  });

  final String tabId;
  final VerticalFiltersSpec spec;
  final String? selectedId;

  @override
  State<_VerticalFiltersPanel> createState() => _VerticalFiltersPanelState();
}

class _VerticalFiltersPanelState extends State<_VerticalFiltersPanel> {
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List<FocusNode>.generate(
      widget.spec.options.length,
      (i) => FocusNode(debugLabel: 'vf-${widget.tabId}-$i'),
    );
    if (_focusNodes.isNotEmpty) {
      ShellTvFocus.verticalFilterRailFirst = _focusNodes.first;
      ShellTvFocus.verticalFilterRailTabId = widget.tabId;
    }
    for (var i = 0; i < widget.spec.options.length; i++) {
      ShellTvFocus.verticalFilterRailById[widget.spec.options[i].id] =
          _focusNodes[i];
    }
  }

  @override
  void didUpdateWidget(covariant _VerticalFiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId == widget.tabId &&
        oldWidget.spec.options.length == widget.spec.options.length) {
      return;
    }
    _disposeFocusNodes();
    _focusNodes = List<FocusNode>.generate(
      widget.spec.options.length,
      (i) => FocusNode(debugLabel: 'vf-${widget.tabId}-$i'),
    );
    if (_focusNodes.isNotEmpty) {
      ShellTvFocus.verticalFilterRailFirst = _focusNodes.first;
      ShellTvFocus.verticalFilterRailTabId = widget.tabId;
    }
    for (var i = 0; i < widget.spec.options.length; i++) {
      ShellTvFocus.verticalFilterRailById[widget.spec.options[i].id] =
          _focusNodes[i];
    }
  }

  void _disposeFocusNodes() {
    if (_focusNodes.isNotEmpty &&
        identical(ShellTvFocus.verticalFilterRailFirst, _focusNodes.first)) {
      ShellTvFocus.verticalFilterRailFirst = null;
      ShellTvFocus.verticalFilterRailTabId = null;
    }
    for (final opt in widget.spec.options) {
      final node = ShellTvFocus.verticalFilterRailById[opt.id];
      if (node != null && _focusNodes.contains(node)) {
        ShellTvFocus.verticalFilterRailById.remove(opt.id);
      }
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
  }

  @override
  void dispose() {
    _disposeFocusNodes();
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
        final items = widget.spec.toLogoMenuItems(
          leadingFor: (o) => VerticalFilterLogoMark(
            option: o,
            packSourceUrl: widget.spec.packSourceUrl,
            width: ShellTokens.shellProviderTileWidth,
            height: ShellTokens.shellProviderTileHeight,
            inset: o.inset,
            borderRadius: BorderRadius.circular(6.5),
          ),
        );
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: ShellTokens.shellProviderRailPadV,
                  horizontal: ShellTokens.shellProviderRailPadH,
                ),
                child: LogoMenuRail(
                  width: ShellTokens.shellProviderRailWidth -
                      ShellTokens.shellProviderRailPadH * 2,
                  items: items,
                  selectedId: widget.selectedId,
                  onSelect: (id) => VerticalFiltersRegistry.toggleOption(
                    widget.tabId,
                    id,
                  ),
                  itemBuilder: (context, item, selected) {
                    final i = widget.spec.options
                        .indexWhere((o) => o.id == item.id);
                    if (i < 0) return const SizedBox.shrink();
                    final option = widget.spec.options[i];
                    return FocusTraversalOrder(
                      order: NumericFocusOrder(i.toDouble()),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: i < widget.spec.options.length - 1
                              ? ShellTokens.shellProviderRailGap
                              : 0,
                        ),
                        child: _VerticalFilterTile(
                          tabId: widget.tabId,
                          option: option,
                          packSourceUrl: widget.spec.packSourceUrl,
                          index: i,
                          focusNodes: _focusNodes,
                          selected: selected,
                          onTap: () => VerticalFiltersRegistry.toggleOption(
                            widget.tabId,
                            option.id,
                          ),
                          onFocusNeighbor: _focusTile,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VerticalFilterTile extends StatelessWidget {
  const _VerticalFilterTile({
    required this.tabId,
    required this.option,
    required this.packSourceUrl,
    required this.index,
    required this.focusNodes,
    required this.selected,
    required this.onTap,
    required this.onFocusNeighbor,
  });

  final String tabId;
  final VerticalFilterOption option;
  final String packSourceUrl;
  final int index;
  final List<FocusNode> focusNodes;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<int> onFocusNeighbor;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tileW = ShellTokens.shellProviderTileWidth;
    final tileH = ShellTokens.shellProviderTileHeight;
    final ring = selected ? 2.0 : 0.0;
    final child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: ring,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: VerticalFilterLogoMark(
          option: option,
          packSourceUrl: packSourceUrl,
          width: tileW - ring * 2,
          height: tileH - ring * 2,
          inset: option.inset,
          borderRadius: BorderRadius.circular(6.5),
        ),
      ),
    );

    if (!policy.useFocusableMoodChips) {
      return GestureDetector(onTap: onTap, child: child);
    }

    return shellFocusableTap(
      context: context,
      focusNode: focusNodes[index],
      listIndex: index,
      onTap: onTap,
      onUpEdge: index > 0 ? () => onFocusNeighbor(index - 1) : null,
      onDownEdge: index < focusNodes.length - 1
          ? () => onFocusNeighbor(index + 1)
          : null,
      onLeftEdge: () => ShellTvFocus.focusNavTab(tabId),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (selected)
            const Positioned(
              top: 4,
              right: 4,
              child: _FilterSelectedCheck(),
            ),
        ],
      ),
    );
  }
}

class _FilterSelectedCheck extends StatelessWidget {
  const _FilterSelectedCheck();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: CustomPaint(
          size: const Size(12, 10),
          painter: _LineCheckPainter(color: Colors.white),
        ),
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
