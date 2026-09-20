import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:forja_foundation/widgets/guide/guide_browse_text_field.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/widgets/guide/guide_tv_keys.dart';

class ChannelSearchOverlay extends StatefulWidget {
  const ChannelSearchOverlay({
    super.key,
    required this.guide,
    required this.currentChannelId,
    required this.onChannelSelected,
    required this.onClose,
    this.isTv = false,
  });

  final ChannelGuide guide;
  final String currentChannelId;
  final ValueChanged<GuideChannel> onChannelSelected;
  final VoidCallback onClose;

  /// D-pad / focus-graph surface — host wires from shell input policy.
  final bool isTv;

  static const int maxVisibleResults = 8;
  static const double resultRowHeight = 58;
  static const double panelRadius = 12;
  static const double panelWidth = 400;

  /// HardwareKeyboard steals Focus onKey for goBack — player overlay gate
  /// calls this. Returns `true` when Back moved from the result list back to
  /// the search field (caller should not close the overlay).
  static bool tryConsumeBackToField() =>
      _ChannelSearchOverlayState.tryConsumeBackToField();

  @override
  State<ChannelSearchOverlay> createState() =>
      _ChannelSearchOverlayState();
}

class _ChannelSearchOverlayState extends State<ChannelSearchOverlay> {
  static _ChannelSearchOverlayState? _active;

  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  final FocusNode _overlayFocus = FocusNode();
  final ScrollController _resultScroll = ScrollController();
  final Map<int, GlobalKey> _resultKeys = {};

  int _focusedResultIndex = 0;
  /// When true, D-pad / OK target the result list (not the search field).
  bool _listFocused = false;

  static bool tryConsumeBackToField() {
    final s = _active;
    if (s == null || !s.mounted) return false;
    if (!s._listFocused) return false;
    s._focusSearchField();
    return true;
  }

  static Color get _panelTint => Colors.transparent;
  static Color get _accent => ForjaShellColors.brandGreen;
  static Color get _panelSurface => GuideChromeStyle.surfaceGlass;

  @override
  void initState() {
    super.initState();
    _active = this;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _queryCtrl.dispose();
    _queryFocus.dispose();
    _overlayFocus.dispose();
    _resultScroll.dispose();
    super.dispose();
  }

  List<GuideChannel> get _results =>
      widget.guide.searchChannels(_queryCtrl.text);

  void _resetFocusIndex() {
    final n = _results.length;
    _focusedResultIndex = n == 0 ? 0 : _focusedResultIndex.clamp(0, n - 1);
  }

  void _onQueryChanged(String _) {
    setState(() {
      _listFocused = false;
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
      duration: animate
          ? ForjaMotionTheme.of(context).fillOnly.duration
          : Duration.zero,
      curve: Curves.easeOut,
      alignment: 0.35,
    );
  }

  /// Leave the search field and highlight the first (or current) result.
  /// Does **not** open the channel — OK on a highlighted row does that.
  void _focusResultsList({int? index}) {
    final results = _results;
    if (results.isEmpty) return;
    setState(() {
      _listFocused = true;
      _focusedResultIndex =
          (index ?? _focusedResultIndex).clamp(0, results.length - 1);
    });
    if (_queryFocus.hasFocus) {
      _queryFocus.unfocus();
    }
    if (_overlayFocus.canRequestFocus) {
      _overlayFocus.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollFocusedIntoView();
    });
  }

  void _focusSearchField() {
    setState(() => _listFocused = false);
    _queryFocus.requestFocus();
  }

  void _moveResultFocus(int delta) {
    final results = _results;
    if (results.isEmpty) return;
    if (!_listFocused) {
      _focusResultsList(index: delta > 0 ? 0 : results.length - 1);
      return;
    }
    final next = _focusedResultIndex + delta;
    if (next < 0) {
      _focusSearchField();
      return;
    }
    if (next >= results.length) return;
    setState(() => _focusedResultIndex = next);
    _scrollFocusedIntoView();
  }

  void _activateFocusedResult() {
    if (!_listFocused) return;
    final results = _results;
    if (results.isEmpty) return;
    widget.onChannelSelected(
      results[_focusedResultIndex.clamp(0, results.length - 1)],
    );
  }

  KeyEventResult _onResultListKey(KeyEvent event) {
    if (!guideIsNavigationKey(event)) return KeyEventResult.ignored;
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
    if (guideIsActivateKey(event) ||
        key == LogicalKeyboardKey.space) {
      _activateFocusedResult();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onOverlayKey(FocusNode node, KeyEvent event) {
    if (!guideIsNavigationKey(event)) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      if (_listFocused) {
        _focusSearchField();
        return KeyEventResult.handled;
      }
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (!_listFocused && _results.isNotEmpty) {
      // Overlay may hold focus briefly after submit — treat OK/↓ as enter list.
      if (guideIsActivateKey(event) ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _focusResultsList(index: 0);
        return KeyEventResult.handled;
      }
    }
    return _onResultListKey(event);
  }

  KeyEventResult _onSearchFieldKey(FocusNode node, KeyEvent event) {
    if (!guideIsNavigationKey(event)) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (_results.isEmpty) return KeyEventResult.ignored;

    // ↓ or OK/Enter from the field: land on the first result — never open it.
    // Do not treat Space here — that inserts a character while typing.
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusResultsList(index: 0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.select) {
      _focusResultsList(index: 0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onSearchSubmitted(String _) {
    if (_results.isEmpty) return;
    _focusResultsList(index: 0);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final showResults = _queryCtrl.text.trim().isNotEmpty;
    final listHeight = showResults && results.isNotEmpty
        ? (results.length.clamp(1, ChannelSearchOverlay.maxVisibleResults) *
            ChannelSearchOverlay.resultRowHeight)
        : 0.0;
    final panelWidth = ChannelSearchOverlay.panelWidth
        .clamp(0.0, MediaQuery.sizeOf(context).width - 32)
        .toDouble();

    // Caller must wrap with Positioned.fill as a direct Stack child.
    return Focus(
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
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          Center(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(ChannelSearchOverlay.panelRadius),
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _panelSurface,
                      borderRadius: BorderRadius.circular(
                        ChannelSearchOverlay.panelRadius,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SizedBox(
                      width: panelWidth,
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
                                style: GoogleFonts.plusJakartaSans(
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
                                  itemExtent: ChannelSearchOverlay
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
                                      focused: _listFocused &&
                                          i == _focusedResultIndex,
                                      onTap: () {
                                        setState(() {
                                          _listFocused = true;
                                          _focusedResultIndex = i;
                                        });
                                        widget.onChannelSelected(results[i]);
                                      },
                                      onHover: () {
                                        if (_focusedResultIndex == i &&
                                            _listFocused) {
                                          return;
                                        }
                                        setState(() {
                                          _listFocused = true;
                                          _focusedResultIndex = i;
                                        });
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
                  style: GuideChromeStyle.overlayTitle.copyWith(
                    color: _accent,
                    fontSize: 16,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Builder(
                    builder: (context) {
                      final close = Button(
                        variant: ButtonVariant.plainIcon,
                        size: ButtonSize.icon,
                        icon: Icons.close_rounded,
                        compact: true,
                        color: Colors.white70,
                        iconSize: 18,
                        height: 32,
                        onPressed: widget.onClose,
                      );
                      return widget.isTv
                          ? ExcludeFocus(child: close)
                          : close;
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GuideBrowseTextField(
              tvBrowse: widget.isTv,
              controller: _queryCtrl,
              focusNode: _queryFocus,
              onChanged: _onQueryChanged,
              onSubmitted: _onSearchSubmitted,
              onEscape: widget.onClose,
              onKeyEvent: _onSearchFieldKey,
              browsePlaceholder: 'Search channels or categories…',
              browseHintStyle:
                  GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 13),
              caretHeight: 18,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white60),
                hintText: 'Search channels or categories…',
                hintStyle:
                    GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 13),
                suffixIcon: _queryCtrl.text.isEmpty
                    ? null
                    : Builder(
                        builder: (context) {
                          final clear = Button(
                            variant: ButtonVariant.plainIcon,
                            size: ButtonSize.icon,
                            icon: Icons.close_rounded,
                            compact: true,
                            color: Colors.white54,
                            iconSize: 18,
                            height: 32,
                            onPressed: () {
                              _queryCtrl.clear();
                              _onQueryChanged('');
                              _queryFocus.requestFocus();
                            },
                          );
                          return widget.isTv
                              ? ExcludeFocus(child: clear)
                              : clear;
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

  final GuideChannel channel;
  final String groupName;
  final bool active;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);

  static Color get _accent => ForjaShellColors.brandGreen;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _setHovered(true);
        widget.onHover();
      },
      onExit: (_) => _setHovered(false),
      // No hover/focus scale — panel ClipRRect would clip the lift into the pad.
      // Green left bar + fill already mark focus.
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) {
          final active = widget.active;
          final focused = widget.focused || _hoveredN.value;
          final highlighted = active || focused;
          return InkWell(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? _accent.withValues(alpha: 0.18)
                    : focused
                        ? _accent.withValues(alpha: 0.10)
                        : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: active || focused ? _accent : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _ChannelLogo(url: widget.channel.logoUrl ?? ''),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: focused
                                ? _accent
                                : active
                                    ? Colors.white
                                    : Colors.white60,
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
                            style: GoogleFonts.plusJakartaSans(
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
          );
        },
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url});

  final String url;
  static const double width = 60;
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Only cacheWidth — both dims force a stretched decode.
    final cacheW = (width * dpr).round().clamp(1, 512);
    return SizedBox(
      width: width,
      height: height,
      child: ForjaNetworkImage(
        key: ValueKey(url),
        url: url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        memCacheWidth: cacheW,
        filterQuality: FilterQuality.medium,
        useOldImageOnUrlChange: false,
        placeholder: _placeholder(),
        error: _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return const SizedBox(
      width: width,
      height: height,
      child: Icon(
        Icons.live_tv_rounded,
        color: Colors.white38,
        size: height * 0.5,
      ),
    );
  }
}
