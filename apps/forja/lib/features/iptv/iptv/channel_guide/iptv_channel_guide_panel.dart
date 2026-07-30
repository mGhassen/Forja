import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';

enum _GuideStep { groups, channels }
enum _FocusColumn { groups, channels }

class IptvChannelGuidePanel extends StatefulWidget {
  const IptvChannelGuidePanel({
    super.key,
    required this.guide,
    required this.selectedGroupId,
    required this.currentChannelId,
    required this.onGroupSelected,
    required this.onChannelSelected,
    required this.onClose,
  });

  final IptvChannelGuide guide;
  final String selectedGroupId;
  final String currentChannelId;
  final ValueChanged<String> onGroupSelected;
  final ValueChanged<IptvGuideChannel> onChannelSelected;
  final VoidCallback onClose;

  static const double wideBreakpoint = 700;
  /// Compact overlay — leaves video visible on the right (was 660).
  static const double panelWidthWide = 480;
  static const double panelWidthNarrow = 300;
  /// Desktop/phone floating inset — TV uses a flush full-height left rail.
  static const double panelEdgeGap = 10;
  static const double panelRadius = 12;
  /// Phone only — cap guide height so it does not fill the player.
  /// Desktop fills from chrome inset to the bottom edge gap.
  static const double panelHeightFractionPhone = 0.72;
  static const double panelVerticalGap = 28;
  /// Fixed channel row height (padding + logo) — dense for TV D-pad lists.
  static const double channelRowExtent = 52;
  static const double channelListPaddingV = 10;
  /// Fixed group row height for reliable jump-to-index scrolling.
  static const double groupRowExtent = 40;
  static const double groupListPaddingV = 10;
  /// Keep focused row fully inside the viewport (focus bar not clipped).
  static const double listFocusMargin = 8;

  @override
  State<IptvChannelGuidePanel> createState() => _IptvChannelGuidePanelState();
}

class _IptvChannelGuidePanelState extends State<IptvChannelGuidePanel> {
  _GuideStep _step = _GuideStep.groups;
  _FocusColumn _focusColumn = _FocusColumn.channels;
  final ScrollController _groupScroll = ScrollController();
  final ScrollController _channelScroll = ScrollController();
  final FocusNode _focusNode = FocusNode();

  int _focusedGroupIndex = 0;
  int _focusedChannelIndex = 0;

  /// Local browse group — D-pad through groups updates this without parent setState.
  late String _browseGroupId;

  final Map<String, bool> _health = {};
  final Set<String> _healthInFlight = {};
  final List<IptvGuideChannel> _healthQueue = [];
  final Map<String, Timer> _healthDebounce = {};
  static const _maxHealthChecks = 2;
  static const _healthCheckDelay = Duration(milliseconds: 450);

  static const Color _groupsTint = Color(0xE00C0C12);
  static const Color _channelsTint = Color(0xE016161F);
  /// Brand green — matches catalog sidebar / TV focus chrome (not gray navUnderline).
  static Color get _accent => ForjaShellColors.brandGreen;
  static Color get _panelSurface =>
      ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.94);

  @override
  void initState() {
    super.initState();
    // Always open on the playing channel's category when known.
    _browseGroupId =
        widget.guide.groupIdForChannel(widget.currentChannelId) ??
            widget.selectedGroupId;
    _health.addAll(widget.guide.streamHealth);
    _syncFocusIndices();
    _focusNode.addListener(_reclaimFocusIfLost);
    _scheduleRevealPlaying();
  }

  void _claimFocus() {
    if (!mounted || !_focusNode.canRequestFocus) return;
    _focusNode.requestFocus();
  }

  /// Keep D-pad on the panel root - InkWell / chrome must not steal keys.
  void _reclaimFocusIfLost() {
    if (!mounted || _focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
  }

  /// ListView.builder only mounts visible rows — [ensureVisible] can't reach
  /// off-screen keys. Jump by fixed [itemExtent] instead; retry until attached.
  void _scheduleRevealPlaying({bool animate = false}) {
    void attempt({int tries = 0}) {
      if (!mounted) return;
      final ready = _revealPlaying(animate: animate);
      if (ready) {
        _claimFocus();
        return;
      }
      if (tries < 12) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => attempt(tries: tries + 1));
      } else {
        _claimFocus();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  bool _revealPlaying({bool animate = false}) {
    if (!_groupScroll.hasClients) return false;

    // Wait for layout — maxScrollExtent is 0 until the list measures.
    if (_focusedGroupIndex > 0 &&
        _groupScroll.position.maxScrollExtent <= 0) {
      return false;
    }

    final needChannels = _wide || _step == _GuideStep.channels;
    if (needChannels) {
      if (!_channelScroll.hasClients) return false;
      if (_focusedChannelIndex > 0 &&
          _channelScroll.position.maxScrollExtent <= 0) {
        return false;
      }
    }

    _jumpListToIndex(
      _groupScroll,
      index: _focusedGroupIndex,
      itemExtent: IptvChannelGuidePanel.groupRowExtent,
      paddingV: IptvChannelGuidePanel.groupListPaddingV,
      alignment: 0.45,
      animate: animate,
    );

    if (needChannels) {
      _jumpListToIndex(
        _channelScroll,
        index: _focusedChannelIndex,
        itemExtent: IptvChannelGuidePanel.channelRowExtent,
        paddingV: IptvChannelGuidePanel.channelListPaddingV,
        alignment: 0.35,
        animate: animate,
      );
    }
    return true;
  }

  /// Scroll only when the focused row would be clipped — leap to keep it inside
  /// [listFocusMargin]. Instant jump on TV (no tween stutter / missing focus).
  void _jumpListToIndex(
    ScrollController controller, {
    required int index,
    required double itemExtent,
    required double paddingV,
    required double alignment,
    bool animate = false,
  }) {
    if (!controller.hasClients || index < 0) return;
    final position = controller.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final margin = IptvChannelGuidePanel.listFocusMargin;
    final itemTop = paddingV + index * itemExtent;
    final itemBottom = itemTop + itemExtent;
    final viewTop = position.pixels;
    final viewBottom = viewTop + viewport;
    double? target;
    if (itemTop < viewTop + margin) {
      target = itemTop - margin;
    } else if (itemBottom > viewBottom - margin) {
      target = itemBottom - viewport + margin;
    }
    // First reveal / open-on-playing still centers via [alignment].
    if (target == null && alignment > 0) {
      final preferred = paddingV +
          index * itemExtent -
          (viewport - itemExtent) * alignment;
      final inView = itemTop >= viewTop + margin &&
          itemBottom <= viewBottom - margin;
      if (!inView) target = preferred;
    }
    if (target == null) return;
    final offset = target.clamp(0.0, position.maxScrollExtent);
    if ((offset - position.pixels).abs() < 0.5) return;
    // TV D-pad: always jump. Animated scroll hides the focus highlight mid-tween.
    final useAnimate = animate && !iptvUseTvFocus(context);
    if (useAnimate) {
      controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else {
      controller.jumpTo(offset);
    }
  }

  @override
  void didUpdateWidget(covariant IptvChannelGuidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGroupId != widget.selectedGroupId) {
      _browseGroupId = widget.selectedGroupId;
      _syncFocusIndices();
      _scheduleRevealPlaying(animate: true);
    } else if (oldWidget.currentChannelId != widget.currentChannelId) {
      final playingGroup =
          widget.guide.groupIdForChannel(widget.currentChannelId);
      if (playingGroup != null && playingGroup != _browseGroupId) {
        _browseGroupId = playingGroup;
        _syncFocusIndices();
        _scheduleRevealPlaying(animate: true);
      } else {
        _syncFocusIndices(channelOnly: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _revealPlaying(animate: true);
        });
      }
    }
  }

  @override
  void dispose() {
    for (final t in _healthDebounce.values) {
      t.cancel();
    }
    _healthDebounce.clear();
    _focusNode.removeListener(_reclaimFocusIfLost);
    _focusNode.dispose();
    _groupScroll.dispose();
    _channelScroll.dispose();
    super.dispose();
  }

  void _syncFocusIndices({bool channelOnly = false}) {
    if (!channelOnly) {
      final gIdx =
          widget.guide.groups.indexWhere((g) => g.id == _browseGroupId);
      if (gIdx >= 0) _focusedGroupIndex = gIdx;
    }
    final channels = widget.guide.channelsForGroup(_browseGroupId);
    final cIdx =
        channels.indexWhere((c) => c.id == widget.currentChannelId);
    if (cIdx >= 0) {
      _focusedChannelIndex = cIdx;
      if (!channelOnly) _focusColumn = _FocusColumn.channels;
    } else if (!channelOnly) {
      _focusedChannelIndex = 0;
    }
  }

  /// Move group highlight only — does not rebuild the channel list / logos.
  /// [scroll] false = hover: highlight in place, do not jump the list.
  void _focusGroupAt(
    int index, {
    bool animateScroll = true,
    bool scroll = true,
  }) {
    final n = widget.guide.groups.length;
    if (n == 0) return;
    final next = index.clamp(0, n - 1);
    if (next == _focusedGroupIndex) {
      if (scroll) _scrollFocusedGroupIntoView(animate: animateScroll);
      return;
    }
    // Jump before rebuild so focus chrome never paints off-screen for a frame.
    _focusedGroupIndex = next;
    if (scroll) _scrollFocusedGroupIntoView(animate: animateScroll);
    setState(() {});
  }

  /// Local-only browse — updates channel list without parent player rebuild.
  /// Use for click / OK / → — not for hover or D-pad ↑/↓ on groups.
  void _browseGroup(String groupId, {bool animateScroll = true}) {
    final gIdx = widget.guide.groups.indexWhere((g) => g.id == groupId);
    final nextFocus = gIdx >= 0 ? gIdx : _focusedGroupIndex;
    final groupChanged = groupId != _browseGroupId;
    if (!groupChanged && nextFocus == _focusedGroupIndex) {
      return;
    }
    setState(() {
      _focusedGroupIndex = nextFocus;
      if (groupChanged) {
        _browseGroupId = groupId;
        _focusedChannelIndex = 0;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocusedGroupIntoView(animate: animateScroll);
    });
  }

  /// Commit browse group to parent (OK / Right / tap).
  void _selectGroup(String groupId, {bool animateScroll = true}) {
    _browseGroup(groupId, animateScroll: animateScroll);
    if (groupId != widget.selectedGroupId) {
      widget.onGroupSelected(groupId);
    }
  }

  void _scrollFocusedGroupIntoView({bool animate = false}) {
    if (_focusedGroupIndex < 0 || !_groupScroll.hasClients) return;
    _jumpListToIndex(
      _groupScroll,
      index: _focusedGroupIndex,
      itemExtent: IptvChannelGuidePanel.groupRowExtent,
      paddingV: IptvChannelGuidePanel.groupListPaddingV,
      alignment: 0,
      animate: animate,
    );
  }

  EdgeInsets _panelPadding(BuildContext context) {
    // Android TV: flush left rail from top to bottom (no floating inset).
    if (iptvUseTvFocus(context)) return EdgeInsets.zero;
    // Desktop: top chrome + edge gap, bottom flush to a thin edge gap so the
    // panel reaches the bottom of the player. Phone keeps a larger bottom gap.
    final desktop = DesktopWindowChrome.isDesktop;
    return EdgeInsets.only(
      top: DesktopWindowChrome.topInset(context) +
          IptvChannelGuidePanel.panelVerticalGap,
      bottom: desktop
          ? IptvChannelGuidePanel.panelEdgeGap
          : IptvChannelGuidePanel.panelVerticalGap,
      left: IptvChannelGuidePanel.panelEdgeGap,
    );
  }

  double _panelHeight(BuildContext context) {
    final pad = _panelPadding(context);
    final available =
        MediaQuery.sizeOf(context).height - pad.top - pad.bottom;
    if (iptvUseTvFocus(context)) return available;
    // Desktop: full height to the bottom. Phone: capped floating overlay.
    if (DesktopWindowChrome.isDesktop) return available;
    final target =
        available * IptvChannelGuidePanel.panelHeightFractionPhone;
    return target.clamp(280.0, available).toDouble();
  }

  IptvGuideChannel? get _currentChannel {
    for (final c in widget.guide.channels) {
      if (c.id == widget.currentChannelId) return c;
    }
    return null;
  }

  String? _playUrlFor(IptvGuideChannel ch) {
    final portal = widget.guide.xtreamPortal;
    if (ch.xtreamStream != null && portal != null) {
      return IptvClient.streamUrl(portal.portal, ch.xtreamStream!);
    }
    final url = ch.playUrl;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  void _scheduleHealthCheck(IptvGuideChannel ch) {
    if (_health.containsKey(ch.id)) return;
    if (_healthInFlight.contains(ch.id)) return;
    _healthDebounce[ch.id]?.cancel();
    _healthDebounce[ch.id] = Timer(_healthCheckDelay, () {
      _healthDebounce.remove(ch.id);
      _enqueueHealthCheck(ch);
    });
  }

  void _cancelHealthCheck(String channelId) {
    _healthDebounce[channelId]?.cancel();
    _healthDebounce.remove(channelId);
  }

  void _enqueueHealthCheck(IptvGuideChannel ch) {
    if (_health.containsKey(ch.id)) return;
    if (_healthInFlight.contains(ch.id)) return;
    if (_healthInFlight.length >= _maxHealthChecks) {
      if (!_healthQueue.any((x) => x.id == ch.id)) {
        _healthQueue.add(ch);
      }
      return;
    }
    unawaited(_runHealthCheck(ch));
  }

  Future<void> _runHealthCheck(IptvGuideChannel ch) async {
    final url = _playUrlFor(ch);
    if (url == null) return;
    _healthInFlight.add(ch.id);
    try {
      final ok = await IptvAliveChecker.checkOne(url);
      if (!mounted) return;
      setState(() => _health[ch.id] = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _health[ch.id] = false);
    } finally {
      _healthInFlight.remove(ch.id);
      _drainHealthQueue();
    }
  }

  void _drainHealthQueue() {
    while (_healthQueue.isNotEmpty &&
        _healthInFlight.length < _maxHealthChecks) {
      final next = _healthQueue.removeAt(0);
      if (!_health.containsKey(next.id)) {
        unawaited(_runHealthCheck(next));
      }
    }
  }

  List<IptvGuideChannel> get _visibleChannels =>
      widget.guide.channelsForGroup(_browseGroupId);

  bool get _wide =>
      MediaQuery.sizeOf(context).width >= IptvChannelGuidePanel.wideBreakpoint;

  void _scrollToFocused({bool animate = true, bool groupsOnly = false}) {
    _scrollFocusedGroupIntoView(animate: animate);
    if (!groupsOnly && _focusColumn == _FocusColumn.channels) {
      if (!_channelScroll.hasClients) return;
      _jumpListToIndex(
        _channelScroll,
        index: _focusedChannelIndex,
        itemExtent: IptvChannelGuidePanel.channelRowExtent,
        paddingV: IptvChannelGuidePanel.channelListPaddingV,
        alignment: 0,
        animate: animate,
      );
    }
  }

  void _close() {
    _focusNode.removeListener(_reclaimFocusIfLost);
    widget.onClose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (!_wide && _step == _GuideStep.channels) {
        setState(() => _step = _GuideStep.groups);
        WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
        return KeyEventResult.handled;
      }
      _close();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusRight();
      return KeyEventResult.handled;
    }
    if (shellTvIsActivateKey(event)) {
      _activateFocused();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _moveFocus(int delta) {
    if (_wide) {
      if (_focusColumn == _FocusColumn.groups) {
        final n = widget.guide.groups.length;
        if (n == 0) return;
        // Focus chrome only — channel logos stay on last OK/→ group.
        _focusGroupAt(_focusedGroupIndex + delta);
        return;
      } else {
        final n = _visibleChannels.length;
        if (n == 0) return;
        final next =
            (_focusedChannelIndex + delta).clamp(0, n - 1);
        if (next == _focusedChannelIndex) return;
        _focusedChannelIndex = next;
        _scrollToFocused();
        setState(() {});
        return;
      }
    } else if (_step == _GuideStep.groups) {
      final n = widget.guide.groups.length;
      if (n == 0) return;
      _focusGroupAt(_focusedGroupIndex + delta, animateScroll: true);
      return;
    } else {
      final n = _visibleChannels.length;
      if (n == 0) return;
      final next = (_focusedChannelIndex + delta).clamp(0, n - 1);
      if (next == _focusedChannelIndex) return;
      _focusedChannelIndex = next;
      _scrollToFocused();
      setState(() {});
    }
  }

  String _headerGroupName() {
    final groups = widget.guide.groups;
    if (groups.isEmpty) {
      return widget.guide.groupById(_browseGroupId)?.name ?? 'Uncategorized';
    }
    if (_wide && _focusColumn == _FocusColumn.groups) {
      return groups[_focusedGroupIndex.clamp(0, groups.length - 1)].name;
    }
    if (!_wide && _step == _GuideStep.groups) {
      return groups[_focusedGroupIndex.clamp(0, groups.length - 1)].name;
    }
    return widget.guide.groupById(_browseGroupId)?.name ?? 'Uncategorized';
  }

  void _focusLeft() {
    if (_wide) {
      if (_focusColumn == _FocusColumn.channels) {
        setState(() => _focusColumn = _FocusColumn.groups);
        _scrollToFocused(groupsOnly: true);
      }
      return;
    }
    if (_step == _GuideStep.channels) {
      setState(() => _step = _GuideStep.groups);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focusNode.canRequestFocus) _focusNode.requestFocus();
      });
    }
  }

  void _focusRight() {
    if (_wide) {
      if (_focusColumn == _FocusColumn.groups) {
        // Commit focused group (↑/↓ no longer browses) then enter channels.
        final g = widget.guide.groups[_focusedGroupIndex];
        _selectGroup(g.id);
        setState(() => _focusColumn = _FocusColumn.channels);
        _scrollToFocused();
        return;
      }
      // Channels column - Right returns focus to the player.
      _close();
      return;
    }
    if (_step == _GuideStep.groups) {
      final g = widget.guide.groups[_focusedGroupIndex];
      _selectGroup(g.id);
      setState(() => _step = _GuideStep.channels);
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
      return;
    }
    // Channels step - Right returns focus to the player.
    _close();
  }

  void _activateFocused() {
    if (_wide) {
      if (_focusColumn == _FocusColumn.groups) {
        final g = widget.guide.groups[_focusedGroupIndex];
        _selectGroup(g.id);
        setState(() => _focusColumn = _FocusColumn.channels);
        _scrollToFocused();
        return;
      }
      final channels = _visibleChannels;
      if (_focusedChannelIndex < channels.length) {
        widget.onChannelSelected(channels[_focusedChannelIndex]);
      }
      return;
    }

    if (_step == _GuideStep.groups) {
      final g = widget.guide.groups[_focusedGroupIndex];
      _selectGroup(g.id);
      setState(() => _step = _GuideStep.channels);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focusNode.canRequestFocus) _focusNode.requestFocus();
      });
      return;
    }
    final channels = _visibleChannels;
    if (_focusedChannelIndex < channels.length) {
      widget.onChannelSelected(channels[_focusedChannelIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = _wide;
    final tv = iptvUseTvFocus(context);

    // Caller must wrap with Positioned.fill as a direct Stack child.
    return FocusScope(
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        // Custom D-pad highlight - do not let Material/InkWell take focus or
        // DirectionalFocus will walk Right out of the panel onto the video.
        descendantsAreFocusable: false,
        descendantsAreTraversable: false,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (tv)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _buildPanelShell(wide: wide, tvRail: true),
              )
            else if (DesktopWindowChrome.isDesktop)
              // Dock under window chrome → bottom of the player (no height cap).
              Positioned(
                left: IptvChannelGuidePanel.panelEdgeGap,
                top: DesktopWindowChrome.topInset(context) +
                    IptvChannelGuidePanel.panelVerticalGap,
                bottom: IptvChannelGuidePanel.panelEdgeGap,
                child: _buildPanelShell(wide: wide, tvRail: false),
              )
            else
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: _panelPadding(context),
                  child: SizedBox(
                    height: _panelHeight(context),
                    child: _buildPanelShell(wide: wide, tvRail: false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Flat translucent shell — no [BackdropFilter] over live video (ATV GPU cost).
  Widget _buildPanelShell({required bool wide, required bool tvRail}) {
    final panelWidth = wide
        ? IptvChannelGuidePanel.panelWidthWide
        : IptvChannelGuidePanel.panelWidthNarrow;
    // TV: square full-height rail flush to the left edge.
    final radius = tvRail
        ? BorderRadius.zero
        : const BorderRadius.only(
            topRight: Radius.circular(IptvChannelGuidePanel.panelRadius),
            bottomRight: Radius.circular(IptvChannelGuidePanel.panelRadius),
          );

    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _panelSurface,
            borderRadius: radius,
            border: Border(
              top: tvRail
                  ? BorderSide.none
                  : BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              bottom: tvRail
                  ? BorderSide.none
                  : BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: SizedBox(
            width: panelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(wide: wide),
                Expanded(
                  child: wide ? _buildWideBody() : _buildNarrowBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool wide}) {
    final showBack = !wide && _step == _GuideStep.channels;
    final title = _headerGroupName();
    final playing = _currentChannel;
    final showChannelMeta = wide || _step == _GuideStep.channels;
    final tv = iptvUseTvFocus(context);

    Widget headerBack() {
      if (!showBack) return const SizedBox(width: 40, height: 36);
      final back = iptvBackButton(
        context,
        onTap: () => setState(() => _step = _GuideStep.groups),
        color: Colors.white,
        size: 22,
      );
      return tv ? ExcludeFocus(child: back) : back;
    }

    Widget headerClose() {
      final close = iptvCloseButton(
        context,
        color: Colors.white70,
        onTap: _close,
      );
      return tv ? ExcludeFocus(child: close) : close;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: _channelsTint,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: headerBack(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: IptvShellStyle.overlayTitle.copyWith(
                      color: wide ? _accent : Colors.white,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: headerClose(),
                ),
              ],
            ),
          ),
          if (playing != null && showChannelMeta)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
              child: Row(
                children: [
                  _ChannelLogo(
                    url: playing.logoUrl ?? '',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Now playing',
                          style: GoogleFonts.plusJakartaSans(
                            color: _accent.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          playing.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWideBody() {
    final groups = widget.guide.groups;
    final focusedGroupId = groups.isEmpty
        ? _browseGroupId
        : groups[_focusedGroupIndex.clamp(0, groups.length - 1)].id;
    final pendingCommit = iptvUseTvFocus(context) &&
        _focusColumn == _FocusColumn.groups &&
        focusedGroupId != _browseGroupId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 8,
          child: _panelColumn(
            tint: _groupsTint,
            showDivider: true,
            child: _buildGroupList(),
          ),
        ),
        Expanded(
          flex: 10,
          child: _panelColumn(
            tint: _channelsTint,
            showDivider: false,
            child: pendingCommit
                ? _buildPressOkToOpenGroup()
                : _buildChannelList(_browseGroupId),
          ),
        ),
      ],
    );
  }

  Widget _buildPressOkToOpenGroup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Press OK to open',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _panelColumn({
    required Color tint,
    required bool showDivider,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        border: Border(
          right: showDivider
              ? BorderSide(color: Colors.white.withValues(alpha: 0.08))
              : BorderSide.none,
        ),
      ),
      child: child,
    );
  }

  Widget _buildNarrowBody() {
    if (_step == _GuideStep.groups) {
      return _panelColumn(
        tint: _groupsTint,
        showDivider: false,
        child: _buildGroupList(onPick: (id) {
          _selectGroup(id);
          setState(() => _step = _GuideStep.channels);
        }),
      );
    }
    return _panelColumn(
      tint: _channelsTint,
      showDivider: false,
      child: _buildChannelList(_browseGroupId),
    );
  }

  bool _groupHasPlayingChannel(String groupId) =>
      widget.guide.groupIdForChannel(widget.currentChannelId) == groupId;

  Widget _buildGroupList({ValueChanged<String>? onPick}) {
    return IptvTvScrollbar(
      controller: _groupScroll,
      child: ListView.builder(
        controller: _groupScroll,
        padding: const EdgeInsets.symmetric(
          vertical: IptvChannelGuidePanel.groupListPaddingV,
        ),
        itemCount: widget.guide.groups.length,
        itemExtent: IptvChannelGuidePanel.groupRowExtent,
        addAutomaticKeepAlives: false,
        itemBuilder: (_, i) {
          final g = widget.guide.groups[i];
          final selected = g.id == _browseGroupId;
          final focused = _focusColumn == _FocusColumn.groups &&
              i == _focusedGroupIndex &&
              (_wide || _step == _GuideStep.groups);
          final hasPlaying = _groupHasPlayingChannel(g.id);
          return MouseRegion(
            onEnter: (_) {
              // Hover only highlights in place — never scrolls the list.
              // Click / OK / → opens the group.
              final colChanged =
                  _wide && _focusColumn != _FocusColumn.groups;
              if (colChanged) {
                setState(() => _focusColumn = _FocusColumn.groups);
              }
              _focusGroupAt(i, scroll: false);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_wide) {
                  _focusColumn = _FocusColumn.groups;
                }
                _selectGroup(g.id);
                onPick?.call(g.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: selected
                      ? _accent.withValues(alpha: 0.18)
                      : focused
                          ? _accent.withValues(alpha: 0.10)
                          : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: selected || focused
                          ? _accent
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: focused
                              ? _accent
                              : selected
                                  ? Colors.white
                                  : Colors.white60,
                          fontSize: 13,
                          fontWeight: selected || focused
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (hasPlaying && !selected)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.chevron_right_rounded,
                            color: _accent, size: 18),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelList(String groupId) {
    final channels = widget.guide.channelsForGroup(groupId);
    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No channels',
          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return IptvTvScrollbar(
      controller: _channelScroll,
      child: ListView.builder(
        controller: _channelScroll,
        padding: const EdgeInsets.symmetric(
          vertical: IptvChannelGuidePanel.channelListPaddingV,
        ),
        itemCount: channels.length,
        itemExtent: IptvChannelGuidePanel.channelRowExtent,
        addAutomaticKeepAlives: false,
        itemBuilder: (_, i) {
          final ch = channels[i];
          final active = ch.id == widget.currentChannelId;
          final focused = _focusColumn == _FocusColumn.channels &&
              i == _focusedChannelIndex &&
              (_wide || _step == _GuideStep.channels);
          return _GuideChannelTile(
            channel: ch,
            active: active,
            focused: focused,
            health: _health[ch.id],
            onProbe: () => _scheduleHealthCheck(ch),
            onCancelProbe: () => _cancelHealthCheck(ch.id),
            onHover: () {
              if (_focusColumn == _FocusColumn.channels &&
                  _focusedChannelIndex == i) {
                return;
              }
              setState(() {
                _focusedChannelIndex = i;
                _focusColumn = _FocusColumn.channels;
              });
            },
            onTap: () {
              setState(() {
                _focusedChannelIndex = i;
                _focusColumn = _FocusColumn.channels;
              });
              widget.onChannelSelected(ch);
            },
          );
        },
      ),
    );
  }
}

class _GuideChannelTile extends StatefulWidget {
  const _GuideChannelTile({
    required this.channel,
    required this.active,
    required this.focused,
    required this.onTap,
    required this.onHover,
    required this.onProbe,
    required this.onCancelProbe,
    this.health,
  });

  final IptvGuideChannel channel;
  final bool active;
  final bool focused;
  final bool? health;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onProbe;
  final VoidCallback onCancelProbe;

  @override
  State<_GuideChannelTile> createState() => _GuideChannelTileState();
}

class _GuideChannelTileState extends State<_GuideChannelTile> {
  static Color get _accent => ForjaShellColors.brandGreen;
  static const Color _alive = Color(0xFF22C55E);
  static const Color _dead = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final focused = widget.focused;
    final fill = active
        ? _accent.withValues(alpha: 0.18)
        : focused
            ? _accent.withValues(alpha: 0.10)
            : Colors.transparent;
    final barColor = active || focused ? _accent : Colors.transparent;

    return MouseRegion(
      onEnter: (_) {
        widget.onHover();
        widget.onProbe();
      },
      onExit: (_) => widget.onCancelProbe(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              left: BorderSide(color: barColor, width: 3),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _ChannelLogo(
                    url: widget.channel.logoUrl ?? '',
                    width: 40,
                    height: 40,
                  ),
                  if (widget.health != null)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.health! ? _alive : _dead,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: focused
                        ? _accent
                        : active
                            ? Colors.white
                            : Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        active || focused ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (active)
                Icon(Icons.play_arrow_rounded, color: _accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({
    required this.url,
    this.width = 40,
    this.height = 40,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Only cacheWidth — setting both forces a stretched decode (deformed logos).
    final cacheW = (width * dpr).round().clamp(1, 512);
    final tv = iptvUseTvFocus(context);
    return SizedBox(
      width: width,
      height: height,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        cacheWidth: cacheW,
        filterQuality: tv ? FilterQuality.low : FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return _placeholder();
        },
      ),
    );
  }

  Widget _placeholder() {
    return SizedBox(
      width: width,
      height: height,
      child: Icon(Icons.live_tv_rounded,
          color: Colors.white38, size: height * 0.5),
    );
  }
}
