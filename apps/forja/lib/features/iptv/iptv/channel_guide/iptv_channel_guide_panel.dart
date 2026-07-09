import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_guide_epg.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
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
  static const double panelWidthWide = 480;
  static const double panelWidthNarrow = 300;
  static const double panelEdgeGap = 10;
  static const double panelRadius = 12;

  @override
  State<IptvChannelGuidePanel> createState() => _IptvChannelGuidePanelState();
}

class _IptvChannelGuidePanelState extends State<IptvChannelGuidePanel> {
  _GuideStep _step = _GuideStep.groups;
  _FocusColumn _focusColumn = _FocusColumn.channels;
  final ScrollController _groupScroll = ScrollController();
  final ScrollController _channelScroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final Map<int, GlobalKey> _groupKeys = {};
  final Map<int, GlobalKey> _channelKeys = {};

  int _focusedGroupIndex = 0;
  int _focusedChannelIndex = 0;
  IptvGuideEpgCache? _epgCache;

  final Map<String, bool> _health = {};
  final Set<String> _healthInFlight = {};
  final List<IptvGuideChannel> _healthQueue = [];
  final Map<String, Timer> _healthDebounce = {};
  static const _maxHealthChecks = 2;
  static const _healthCheckDelay = Duration(milliseconds: 450);

  static const Color _groupsTint = Color(0x990C0C12);
  static const Color _channelsTint = Color(0x9916161F);
  static Color get _accent => IptvShellStyle.accent;

  @override
  void initState() {
    super.initState();
    final portal = widget.guide.xtreamPortal;
    if (portal != null) _epgCache = IptvGuideEpgCache(portal);
    _health.addAll(widget.guide.streamHealth);
    _syncFocusIndices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSelectedGroupIntoView(animate: false);
      _scrollToFocused(animate: false);
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant IptvChannelGuidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGroupId != widget.selectedGroupId) {
      _syncFocusIndices();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollSelectedGroupIntoView(animate: true);
        _scrollToFocused(animate: true);
      });
    } else if (oldWidget.currentChannelId != widget.currentChannelId) {
      _syncFocusIndices(channelOnly: true);
    }
  }

  @override
  void dispose() {
    for (final t in _healthDebounce.values) {
      t.cancel();
    }
    _healthDebounce.clear();
    _focusNode.dispose();
    _groupScroll.dispose();
    _channelScroll.dispose();
    super.dispose();
  }

  void _syncFocusIndices({bool channelOnly = false}) {
    if (!channelOnly) {
      final gIdx = widget.guide.groups
          .indexWhere((g) => g.id == widget.selectedGroupId);
      if (gIdx >= 0) _focusedGroupIndex = gIdx;
    }
    final channels = widget.guide.channelsForGroup(widget.selectedGroupId);
    final cIdx =
        channels.indexWhere((c) => c.id == widget.currentChannelId);
    if (cIdx >= 0) {
      _focusedChannelIndex = cIdx;
      if (!channelOnly) _focusColumn = _FocusColumn.channels;
    }
  }

  void _selectGroup(String groupId, {bool animateScroll = true}) {
    final gIdx = widget.guide.groups.indexWhere((g) => g.id == groupId);
    if (gIdx >= 0) _focusedGroupIndex = gIdx;
    if (groupId != widget.selectedGroupId) {
      widget.onGroupSelected(groupId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSelectedGroupIntoView(animate: animateScroll);
    });
  }

  void _scrollSelectedGroupIntoView({bool animate = false}) {
    final gIdx = widget.guide.groups
        .indexWhere((g) => g.id == widget.selectedGroupId);
    if (gIdx < 0) return;
    _focusedGroupIndex = gIdx;
    final ctx = _groupKey(gIdx).currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
      curve: Curves.easeOut,
      alignment: 0.5,
    );
  }

  EdgeInsets _panelPadding(BuildContext context) {
    return EdgeInsets.only(
      top: DesktopWindowChrome.topInset(context),
    );
  }

  double _panelHeight(BuildContext context) {
    final pad = _panelPadding(context);
    return MediaQuery.sizeOf(context).height - pad.top - pad.bottom;
  }

  IptvGuideChannel? get _currentChannel {
    for (final c in widget.guide.channels) {
      if (c.id == widget.currentChannelId) return c;
    }
    return null;
  }

  IptvGuideChannel? get _epgChannel {
    if (_wide || _step == _GuideStep.channels) {
      if (_focusColumn == _FocusColumn.channels) {
        final channels = _visibleChannels;
        if (_focusedChannelIndex >= 0 &&
            _focusedChannelIndex < channels.length) {
          return channels[_focusedChannelIndex];
        }
      }
    }
    return _currentChannel;
  }

  Future<List<EpgEntry>>? _epgFutureFor(IptvGuideChannel? ch) {
    if (_epgCache == null || ch == null) return null;
    final stream = ch.xtreamStream;
    if (stream == null) return null;
    return _epgCache!.load(stream.streamId);
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
      widget.guide.channelsForGroup(widget.selectedGroupId);

  bool get _wide =>
      MediaQuery.sizeOf(context).width >= IptvChannelGuidePanel.wideBreakpoint;

  GlobalKey _groupKey(int index) =>
      _groupKeys.putIfAbsent(index, GlobalKey.new);

  GlobalKey _channelKey(int index) =>
      _channelKeys.putIfAbsent(index, GlobalKey.new);

  void _scrollToFocused({bool animate = true, bool groupsOnly = false}) {
    void reveal(
      GlobalKey key,
      ScrollController controller, {
      double alignment = 0.35,
    }) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
        curve: Curves.easeOut,
        alignment: alignment,
      );
    }

    if (_focusColumn == _FocusColumn.groups || groupsOnly) {
      reveal(_groupKey(_focusedGroupIndex), _groupScroll, alignment: 0.5);
    } else {
      _scrollSelectedGroupIntoView(animate: animate);
    }
    if (!groupsOnly && _focusColumn == _FocusColumn.channels) {
      reveal(_channelKey(_focusedChannelIndex), _channelScroll);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
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
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
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
        final next = (_focusedGroupIndex + delta).clamp(0, n - 1);
        setState(() => _focusedGroupIndex = next);
        _selectGroup(widget.guide.groups[next].id);
        return;
      } else {
        final n = _visibleChannels.length;
        if (n == 0) return;
        setState(() {
          _focusedChannelIndex = (_focusedChannelIndex + delta).clamp(0, n - 1);
        });
      }
    } else if (_step == _GuideStep.groups) {
      final n = widget.guide.groups.length;
      if (n == 0) return;
      final next = (_focusedGroupIndex + delta).clamp(0, n - 1);
      setState(() => _focusedGroupIndex = next);
      _selectGroup(widget.guide.groups[next].id, animateScroll: true);
      return;
    } else {
      final n = _visibleChannels.length;
      if (n == 0) return;
      setState(() {
        _focusedChannelIndex = (_focusedChannelIndex + delta).clamp(0, n - 1);
      });
    }
    _scrollToFocused();
  }

  String _headerGroupName() {
    final groups = widget.guide.groups;
    if (groups.isEmpty) {
      return widget.guide.groupById(widget.selectedGroupId)?.name ??
          'Uncategorized';
    }
    if (_wide && _focusColumn == _FocusColumn.groups) {
      return groups[_focusedGroupIndex.clamp(0, groups.length - 1)].name;
    }
    if (!_wide && _step == _GuideStep.groups) {
      return groups[_focusedGroupIndex.clamp(0, groups.length - 1)].name;
    }
    return widget.guide.groupById(widget.selectedGroupId)?.name ??
        'Uncategorized';
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
    }
  }

  void _focusRight() {
    if (_wide) {
      if (_focusColumn == _FocusColumn.groups) {
        setState(() => _focusColumn = _FocusColumn.channels);
        _scrollToFocused();
      }
      return;
    }
    if (_step == _GuideStep.groups) {
      final g = widget.guide.groups[_focusedGroupIndex];
      _selectGroup(g.id);
      setState(() => _step = _GuideStep.channels);
    }
  }

  void _activateFocused() {
    if (_wide) {
      if (_focusColumn == _FocusColumn.groups) {
        final g = widget.guide.groups[_focusedGroupIndex];
        _selectGroup(g.id);
        setState(() {});
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

    return Positioned.fill(
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: _panelPadding(context),
                child: SizedBox(
                  height: _panelHeight(context),
                  child: _buildFrostedPanelShell(wide: wide),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedPanelShell({required bool wide}) {
    final panelWidth = wide
        ? IptvChannelGuidePanel.panelWidthWide
        : IptvChannelGuidePanel.panelWidthNarrow;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(IptvChannelGuidePanel.panelRadius),
        bottomRight: Radius.circular(IptvChannelGuidePanel.panelRadius),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: Colors.transparent,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          child: Container(
            width: panelWidth,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(IptvChannelGuidePanel.panelRadius),
                bottomRight: Radius.circular(IptvChannelGuidePanel.panelRadius),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            clipBehavior: Clip.antiAlias,
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
    final epgChannel = _epgChannel;
    final epgFuture = _epgFutureFor(epgChannel);
    final showChannelMeta = wide || _step == _GuideStep.channels;

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
                  child: showBack
                      ? ForjaPlainIcon(
                          icon: Icons.arrow_back_rounded,
                          onTap: () =>
                              setState(() => _step = _GuideStep.groups),
                          color: Colors.white,
                          size: 22,
                          hoverScale: 1.15,
                          tooltip: 'Back',
                        )
                      : const SizedBox(width: 40, height: 36),
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
                  child: ForjaCloseButton(
                    color: Colors.white70,
                    onTap: widget.onClose,
                  ),
                ),
              ],
            ),
          ),
          if (playing != null && showChannelMeta)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
              child: Row(
                children: [
                  _ChannelLogo(url: playing.logoUrl ?? '', size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          epgChannel?.id == playing.id
                              ? 'Now playing'
                              : 'Preview',
                          style: GoogleFonts.poppins(
                            color: _accent.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          (epgChannel ?? playing).name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
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
          if (epgFuture != null && showChannelMeta)
            IptvGuideEpgCard(
              key: ValueKey(epgChannel?.id ?? ''),
              future: epgFuture,
            ),
        ],
      ),
    );
  }

  Widget _buildWideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _frostedColumn(
            tint: _groupsTint,
            elevated: false,
            child: _buildGroupList(),
          ),
        ),
        Expanded(
          flex: 7,
          child: _frostedColumn(
            tint: _channelsTint,
            elevated: true,
            child: _buildChannelList(widget.selectedGroupId),
          ),
        ),
      ],
    );
  }

  Widget _frostedColumn({
    required Color tint,
    required bool elevated,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        border: Border(
          right: elevated
              ? BorderSide.none
              : BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(5, 0),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _buildNarrowBody() {
    if (_step == _GuideStep.groups) {
      return _frostedColumn(
        tint: _groupsTint,
        elevated: false,
        child: _buildGroupList(onPick: (id) {
          widget.onGroupSelected(id);
          setState(() => _step = _GuideStep.channels);
        }),
      );
    }
    return _frostedColumn(
      tint: _channelsTint,
      elevated: false,
      child: _buildChannelList(widget.selectedGroupId),
    );
  }

  bool _groupHasPlayingChannel(String groupId) {
    return widget.guide
        .channelsForGroup(groupId)
        .any((c) => c.id == widget.currentChannelId);
  }

  Widget _buildGroupList({ValueChanged<String>? onPick}) {
    return ListView.builder(
      controller: _groupScroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.guide.groups.length,
      itemBuilder: (_, i) {
        final g = widget.guide.groups[i];
        final selected = g.id == widget.selectedGroupId;
        final focused = _focusColumn == _FocusColumn.groups &&
            i == _focusedGroupIndex &&
            (_wide || _step == _GuideStep.groups);
        final hasPlaying = _groupHasPlayingChannel(g.id);
        return KeyedSubtree(
          key: _groupKey(i),
          child: MouseRegion(
            onEnter: (_) {
              setState(() {
                _focusedGroupIndex = i;
                if (_wide) _focusColumn = _FocusColumn.groups;
              });
            },
            child: InkWell(
            onTap: () {
              setState(() {
                _focusedGroupIndex = i;
                if (_wide) _focusColumn = _FocusColumn.groups;
              });
              _selectGroup(g.id);
              onPick?.call(g.id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: selected
                    ? _accent.withValues(alpha: 0.18)
                    : focused
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: selected
                        ? _accent
                        : focused
                            ? Colors.white54
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: selected ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontWeight:
                            selected || focused ? FontWeight.w700 : FontWeight.w400,
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
          ),
        );
      },
    );
  }

  Widget _buildChannelList(String groupId) {
    final channels = widget.guide.channelsForGroup(groupId);
    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No channels',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _channelScroll,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final ch = channels[i];
        final active = ch.id == widget.currentChannelId;
        final focused = _focusColumn == _FocusColumn.channels &&
            i == _focusedChannelIndex &&
            (_wide || _step == _GuideStep.channels);
        return KeyedSubtree(
          key: _channelKey(i),
          child: _GuideChannelTile(
            channel: ch,
            active: active,
            focused: focused,
            health: _health[ch.id],
            epgFuture: active ? _epgFutureFor(ch) : null,
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
          ),
        );
      },
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
    this.epgFuture,
  });

  final IptvGuideChannel channel;
  final bool active;
  final bool focused;
  final bool? health;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onProbe;
  final VoidCallback onCancelProbe;
  final Future<List<EpgEntry>>? epgFuture;

  @override
  State<_GuideChannelTile> createState() => _GuideChannelTileState();
}

class _GuideChannelTileState extends State<_GuideChannelTile> {
  bool _hovered = false;

  static Color get _accent => IptvShellStyle.accent;
  static const Color _alive = Color(0xFF22C55E);
  static const Color _dead = Color(0xFFEF4444);

  bool get _showHealth => widget.active || widget.focused || _hovered;

  @override
  void didUpdateWidget(covariant _GuideChannelTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldProbe = widget.active || widget.focused;
    final wasProbing = oldWidget.active || oldWidget.focused;
    if (shouldProbe && !wasProbing) {
      widget.onProbe();
    } else if (!shouldProbe && wasProbing && !_hovered) {
      widget.onCancelProbe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final focused = widget.focused;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: MouseRegion(
        onEnter: (_) {
          if (!_hovered) setState(() => _hovered = true);
          widget.onHover();
          widget.onProbe();
        },
        onExit: (_) {
          setState(() => _hovered = false);
          if (!active && !focused) widget.onCancelProbe();
        },
        child: Material(
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          color: active
              ? _accent.withValues(alpha: 0.2)
              : focused
                  ? Colors.white.withValues(alpha: 0.1)
                  : ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: active
                    ? Border.all(
                        color: _accent.withValues(alpha: 0.55),
                        width: 1,
                      )
                    : focused
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          )
                        : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _ChannelLogo(url: widget.channel.logoUrl ?? ''),
                      if (_showHealth && widget.health != null)
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: active || focused ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight:
                                active || focused ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (widget.epgFuture != null)
                          IptvGuideEpgCard(
                              future: widget.epgFuture!, compact: true),
                      ],
                    ),
                  ),
                  if (active)
                    Icon(Icons.play_arrow_rounded, color: _accent, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url, this.size = 40});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return _placeholder();
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.live_tv_rounded,
          color: Colors.white38, size: size * 0.5),
    );
  }
}
