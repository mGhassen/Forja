import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/design/design.dart';

class IptvChannelSearchOverlay extends StatefulWidget {
  const IptvChannelSearchOverlay({
    super.key,
    required this.guide,
    required this.currentChannelId,
    required this.onChannelSelected,
    required this.onClose,
  });

  final IptvChannelGuide guide;
  final String currentChannelId;
  final ValueChanged<IptvGuideChannel> onChannelSelected;
  final VoidCallback onClose;

  static const int maxVisibleResults = 8;
  static const double resultRowHeight = 48;
  static const double panelRadius = 12;
  static const double panelWidth = 400;

  @override
  State<IptvChannelSearchOverlay> createState() =>
      _IptvChannelSearchOverlayState();
}

class _IptvChannelSearchOverlayState extends State<IptvChannelSearchOverlay> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  final FocusNode _overlayFocus = FocusNode();
  final ScrollController _resultScroll = ScrollController();
  final Map<int, GlobalKey> _resultKeys = {};

  int _focusedResultIndex = 0;

  static const Color _panelTint = Color(0x9916161F);
  static Color get _accent => IptvShellStyle.accent;

  @override
  void initState() {
    super.initState();
    _queryFocus.onKeyEvent = _onSearchFieldKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _queryFocus.dispose();
    _overlayFocus.dispose();
    _resultScroll.dispose();
    super.dispose();
  }

  List<IptvGuideChannel> get _results =>
      widget.guide.searchChannels(_queryCtrl.text);

  void _resetFocusIndex() {
    final n = _results.length;
    _focusedResultIndex = n == 0 ? 0 : _focusedResultIndex.clamp(0, n - 1);
  }

  void _onQueryChanged(String _) {
    setState(() {
      _focusedResultIndex = 0;
      _resetFocusIndex();
    });
  }

  GlobalKey _resultKey(int index) =>
      _resultKeys.putIfAbsent(index, GlobalKey.new);

  void _scrollFocusedIntoView({bool animate = true}) {
    final key = _resultKey(_focusedResultIndex);
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
      curve: Curves.easeOut,
      alignment: 0.35,
    );
  }

  void _moveResultFocus(int delta) {
    final results = _results;
    if (results.isEmpty) return;
    setState(() {
      _focusedResultIndex =
          (_focusedResultIndex + delta).clamp(0, results.length - 1);
    });
    _scrollFocusedIntoView();
  }

  void _activateFocusedResult() {
    final results = _results;
    if (results.isEmpty) return;
    widget.onChannelSelected(
      results[_focusedResultIndex.clamp(0, results.length - 1)],
    );
  }

  KeyEventResult _onResultNavigationKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_results.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveResultFocus(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveResultFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activateFocusedResult();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onOverlayKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return _onResultNavigationKey(event);
  }

  KeyEventResult _onSearchFieldKey(FocusNode node, KeyEvent event) {
    final nav = _onResultNavigationKey(event);
    if (nav == KeyEventResult.handled) return nav;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final showResults = _queryCtrl.text.trim().isNotEmpty;
    final listHeight = showResults && results.isNotEmpty
        ? (results.length.clamp(1, IptvChannelSearchOverlay.maxVisibleResults) *
            IptvChannelSearchOverlay.resultRowHeight)
        : 0.0;
    final panelWidth = IptvChannelSearchOverlay.panelWidth
        .clamp(0.0, MediaQuery.sizeOf(context).width - 32)
        .toDouble();

    return Positioned.fill(
      child: Focus(
        focusNode: _overlayFocus,
        autofocus: true,
        onKeyEvent: _onOverlayKey,
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
            Center(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(IptvChannelSearchOverlay.panelRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Material(
                    color: Colors.transparent,
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.5),
                    child: Container(
                      width: panelWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          IptvChannelSearchOverlay.panelRadius,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          if (showResults && results.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              child: Text(
                                'No channels found',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (showResults && results.isNotEmpty)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                              child: SizedBox(
                                height: listHeight,
                                child: ListView.builder(
                                  controller: _resultScroll,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: results.length,
                                  itemExtent: IptvChannelSearchOverlay
                                      .resultRowHeight,
                                  itemBuilder: (_, i) => KeyedSubtree(
                                    key: _resultKey(i),
                                    child: _SearchResultTile(
                                      channel: results[i],
                                      groupName: widget.guide
                                              .groupById(results[i].groupId)
                                              ?.name ??
                                          '',
                                      active: results[i].id ==
                                          widget.currentChannelId,
                                      focused: i == _focusedResultIndex,
                                      onTap: () {
                                        setState(() => _focusedResultIndex = i);
                                        widget.onChannelSelected(results[i]);
                                      },
                                      onHover: () {
                                        if (_focusedResultIndex == i) return;
                                        setState(
                                            () => _focusedResultIndex = i);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      decoration: BoxDecoration(
        color: _panelTint,
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
              alignment: Alignment.center,
              children: [
                Text(
                  'Search',
                  style: IptvShellStyle.overlayTitle.copyWith(
                    color: _accent,
                    fontSize: 16,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: iptvCloseButton(
                    context,
                    color: Colors.white70,
                    onTap: widget.onClose,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _queryCtrl,
              focusNode: _queryFocus,
              autofocus: true,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white60),
                hintText: 'Search channels or categories…',
                hintStyle:
                    GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
                suffixIcon: _queryCtrl.text.isEmpty
                    ? null
                    : iptvCloseButton(
                        context,
                        onTap: () {
                          _queryCtrl.clear();
                          _onQueryChanged('');
                          _queryFocus.requestFocus();
                        },
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _accent.withValues(alpha: 0.55),
                  ),
                ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _activateFocusedResult(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  const _SearchResultTile({
    required this.channel,
    required this.groupName,
    required this.active,
    required this.focused,
    required this.onTap,
    required this.onHover,
  });

  final IptvGuideChannel channel;
  final String groupName;
  final bool active;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _hovered = false;

  static Color get _accent => IptvShellStyle.accent;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final focused = widget.focused || _hovered;
    final highlighted = active || focused;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHover();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: widget.focused ? ShellTokens.focusActiveScale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? _accent.withValues(alpha: 0.18)
                : focused
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: active
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
              _ChannelLogo(url: widget.channel.logoUrl ?? '', size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: highlighted ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontWeight:
                            highlighted ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (widget.groupName.isNotEmpty)
                      Text(
                        widget.groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              if (active)
                Icon(Icons.play_arrow_rounded, color: _accent, size: 18),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url, this.size = 28});

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
      child: Icon(
        Icons.live_tv_rounded,
        color: Colors.white38,
        size: size * 0.5,
      ),
    );
  }
}
