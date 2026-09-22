import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
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
    this.resolvePlayUrl,
    this.probeHealth,
  });

  final ChannelGuide guide;
  final String currentChannelId;
  final ValueChanged<GuideChannel> onChannelSelected;
  final VoidCallback onClose;

  /// D-pad / focus-graph surface — host wires from shell input policy.
  final bool isTv;

  /// Optional play-URL resolve — used when [probeHealth] is null.
  final Future<String?> Function(GuideChannel)? resolvePlayUrl;

  /// Optional health probe — host typically resolves URL then checks alive.
  final Future<bool> Function(GuideChannel)? probeHealth;

  static const int maxVisibleResults = 8;
  static const double resultRowHeight = 58;
  static const double panelRadius = 12;
  static const double panelWidth = 400;

  /// Outer margin so the centered panel never kisses the screen edge.
  static const double panelEdgeMargin = 24;

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

  final Map<String, bool> _health = {};
  final Set<String> _healthInFlight = {};
  final List<GuideChannel> _healthQueue = [];
  final Map<String, Timer> _healthDebounce = {};
  static const _maxHealthChecks = 2;
  /// Same dwell as [ChannelGuidePanel] — skimming ↑/↓ must not probe every row.
  static const _healthCheckDelay = Duration(milliseconds: 350);

  static bool tryConsumeBackToField() {
    final s = _active;
    if (s == null || !s.mounted) return false;
    if (!s._listFocused) return false;
    s._focusSearchField();
    return true;
  }

  static Color get _panelTint => Colors.transparent;
  static Color get _accent => ForjaShellColors.brandGreen;

  @override
  void initState() {
    super.initState();
    _active = this;
    _health.addAll(widget.guide.streamHealth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    for (final t in _healthDebounce.values) {
      t.cancel();
    }
    _healthDebounce.clear();
    _queryCtrl.dispose();
    _queryFocus.dispose();
    _overlayFocus.dispose();
    _resultScroll.dispose();
    super.dispose();
  }

  Future<String?> _playUrlFor(GuideChannel ch) async {
    final resolve = widget.resolvePlayUrl;
    if (resolve != null) {
      return resolve(ch);
    }
    final url = ch.playUrl;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  void _scheduleHealthCheck(GuideChannel ch) {
    if (_healthInFlight.contains(ch.id)) return;
    // Single dwell target — drop timers/queue for channels you already left.
    for (final id in _healthDebounce.keys.toList()) {
      if (id == ch.id) continue;
      _healthDebounce[id]?.cancel();
      _healthDebounce.remove(id);
    }
    _healthQueue.removeWhere((x) => x.id != ch.id);
    _healthDebounce[ch.id]?.cancel();
    _healthDebounce[ch.id] = Timer(_healthCheckDelay, () {
      _healthDebounce.remove(ch.id);
      _enqueueHealthCheck(ch);
    });
  }

  void _cancelHealthCheck(String channelId) {
    _healthDebounce[channelId]?.cancel();
    _healthDebounce.remove(channelId);
    _healthQueue.removeWhere((x) => x.id == channelId);
  }

  void _enqueueHealthCheck(GuideChannel ch) {
    if (_healthInFlight.contains(ch.id)) return;
    if (_healthInFlight.length >= _maxHealthChecks) {
      if (!_healthQueue.any((x) => x.id == ch.id)) {
        _healthQueue.add(ch);
      }
      return;
    }
    unawaited(_runHealthCheck(ch));
  }

  Future<void> _runHealthCheck(GuideChannel ch) async {
    final probe = widget.probeHealth;
    if (probe == null &&
        widget.resolvePlayUrl == null &&
        (ch.playUrl == null || ch.playUrl!.isEmpty)) {
      return;
    }
    _healthInFlight.add(ch.id);
    try {
      bool ok;
      if (probe != null) {
        ok = await probe(ch);
      } else {
        final url = await _playUrlFor(ch);
        if (url == null || url.isEmpty) return;
        ok = true;
      }
      if (!mounted) return;
      if (_health[ch.id] == ok) return;
      setState(() => _health[ch.id] = ok);
    } catch (_) {
      if (!mounted) return;
      if (_health[ch.id] == false) return;
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
      if (!_healthInFlight.contains(next.id)) {
        unawaited(_runHealthCheck(next));
      }
    }
  }

  List<GuideChannel> get _results =>
      widget.guide.searchChannels(_queryCtrl.text);

  void _resetFocusIndex() {
    final n = _results.length;
    _focusedResultIndex = n == 0 ? 0 : _focusedResultIndex.clamp(0, n - 1);
  }

  void _onQueryChanged(String _) {
    for (final id in _healthDebounce.keys.toList()) {
      _cancelHealthCheck(id);
    }
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
    final results = _results;
    if (_listFocused &&
        results.isNotEmpty &&
        _focusedResultIndex >= 0 &&
        _focusedResultIndex < results.length) {
      _cancelHealthCheck(results[_focusedResultIndex].id);
    }
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
    final rowH = GuideChromeStyle.len(
      context,
      ChannelSearchOverlay.resultRowHeight,
    );
    final edge = GuideChromeStyle.len(
      context,
      ChannelSearchOverlay.panelEdgeMargin,
    );
    final screen = MediaQuery.sizeOf(context);
    final maxPanelH = math.max(0.0, screen.height - edge * 2);
    final desiredListH = showResults && results.isNotEmpty
        ? (results.length.clamp(1, ChannelSearchOverlay.maxVisibleResults) *
            rowH)
        : 0.0;
    final panelWidth = GuideChromeStyle.len(
      context,
      ChannelSearchOverlay.panelWidth,
    )
        .clamp(0.0, screen.width - edge * 2)
        .toDouble();
    final radius = GuideChromeStyle.len(
      context,
      ChannelSearchOverlay.panelRadius,
    );

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
          Padding(
            padding: EdgeInsets.all(edge),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: panelWidth,
                  maxHeight: maxPanelH,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: GuideChromeStyle.len(context, 28),
                        spreadRadius: GuideChromeStyle.len(context, -2),
                        offset: Offset(0, GuideChromeStyle.len(context, 6)),
                      ),
                    ],
                  ),
                  child: ForjaFrostedPanel(
                    enableBlur: true,
                    blurSigma: 22,
                    borderRadius: BorderRadius.circular(radius),
                    child: SizedBox(
                      width: panelWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          if (showResults && results.isEmpty)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                GuideChromeStyle.len(context, 16),
                                GuideChromeStyle.len(context, 8),
                                GuideChromeStyle.len(context, 16),
                                GuideChromeStyle.len(context, 20),
                              ),
                              child: Text(
                                'No channels found',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize:
                                      GuideChromeStyle.type(context, 13),
                                ),
                              ),
                            ),
                          if (showResults && results.isNotEmpty)
                            // Same pattern as Material AlertDialog: Flexible
                            // yields to the viewport; shrinkWrap keeps the
                            // panel short when few results fit.
                            Flexible(
                              fit: FlexFit.loose,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.02),
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.08),
                                    ),
                                  ),
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: desiredListH,
                                  ),
                                  child: ListView.builder(
                                    controller: _resultScroll,
                                    shrinkWrap: true,
                                    padding: EdgeInsets.symmetric(
                                      vertical: GuideChromeStyle.len(
                                        context,
                                        4,
                                      ),
                                    ),
                                    itemCount: results.length,
                                    itemExtent: rowH,
                                    itemBuilder: (_, i) => KeyedSubtree(
                                      key: _resultKey(i),
                                      child: _SearchResultTile(
                                        channel: results[i],
                                        groupName: widget.guide
                                                .groupById(
                                                    results[i].groupId)
                                                ?.name ??
                                            '',
                                        active: results[i].id ==
                                            widget.currentChannelId,
                                        focused: _listFocused &&
                                            i == _focusedResultIndex,
                                        health: _health[results[i].id],
                                        onProbe: () => _scheduleHealthCheck(
                                          results[i],
                                        ),
                                        onCancelProbe: () =>
                                            _cancelHealthCheck(
                                          results[i].id,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _listFocused = true;
                                            _focusedResultIndex = i;
                                          });
                                          widget.onChannelSelected(
                                            results[i],
                                          );
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
                            ),
                        ],
                      ),
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
      padding: EdgeInsets.fromLTRB(
        GuideChromeStyle.len(context, 8),
        GuideChromeStyle.len(context, 4),
        GuideChromeStyle.len(context, 8),
        GuideChromeStyle.len(context, 10),
      ),
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
            height: GuideChromeStyle.len(context, 36),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  'Search',
                  style: GuideChromeStyle.overlayTitleOf(context).copyWith(
                    color: _accent,
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
                        iconSize: GuideChromeStyle.len(context, 18),
                        height: GuideChromeStyle.len(context, 32),
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
            padding: EdgeInsets.symmetric(
              horizontal: GuideChromeStyle.len(context, 4),
            ),
            child: GuideBrowseTextField(
              tvBrowse: widget.isTv,
              controller: _queryCtrl,
              focusNode: _queryFocus,
              onChanged: _onQueryChanged,
              onSubmitted: _onSearchSubmitted,
              onEscape: widget.onClose,
              onKeyEvent: _onSearchFieldKey,
              browsePlaceholder: 'Search channels or categories…',
              browseHintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.white30,
                fontSize: widget.isTv
                    ? ShellTokens.formInputHintFontSizeTv
                    : ShellTokens.formInputFontSizeSm,
              ),
              caretHeight: widget.isTv
                  ? ShellTokens.formInputFontSizeTv * 1.5
                  : 18,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: widget.isTv
                    ? ShellTokens.formInputFontSizeTv
                    : ShellTokens.formInputFontSizeSm,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white60,
                  size: widget.isTv
                      ? ShellTokens.formInputIconSizeTv
                      : ShellTokens.formInputIconSize,
                ),
                hintText: 'Search channels or categories…',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.white30,
                  fontSize: widget.isTv
                      ? ShellTokens.formInputHintFontSizeTv
                      : ShellTokens.formInputFontSizeSm,
                ),
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
                            iconSize: widget.isTv
                                ? ShellTokens.formInputIconSizeSmTv
                                : 18,
                            height: widget.isTv
                                ? ShellTokens.controlHeightTv
                                : 32,
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
                contentPadding: EdgeInsets.symmetric(
                  vertical: GuideChromeStyle.len(context, 4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    GuideChromeStyle.len(context, 12),
                  ),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    GuideChromeStyle.len(context, 12),
                  ),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    GuideChromeStyle.len(context, 12),
                  ),
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
    required this.onProbe,
    required this.onCancelProbe,
    this.health,
  });

  final GuideChannel channel;
  final String groupName;
  final bool active;
  final bool focused;
  final bool? health;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onProbe;
  final VoidCallback onCancelProbe;

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);

  static Color get _accent => ForjaShellColors.brandGreen;
  static const Color _alive = Color(0xFF22C55E);
  static const Color _dead = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    // TV / D-pad focus is paint-only — probe when this row opens focused.
    if (widget.focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focused) widget.onProbe();
      });
    }
  }

  @override
  void didUpdateWidget(_SearchResultTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.focused;
    final now = widget.focused;
    final same = oldWidget.channel.id == widget.channel.id;
    if (was && (!now || !same)) oldWidget.onCancelProbe();
    if (now && (!was || !same)) widget.onProbe();
  }

  @override
  void dispose() {
    if (widget.focused) widget.onCancelProbe();
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
        widget.onProbe();
      },
      onExit: (_) {
        _setHovered(false);
        widget.onCancelProbe();
      },
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
              padding: EdgeInsets.symmetric(
                horizontal: GuideChromeStyle.len(context, 12),
                vertical: GuideChromeStyle.len(context, 5),
              ),
              decoration: BoxDecoration(
                color: active
                    ? _accent.withValues(alpha: 0.18)
                    : focused
                        ? _accent.withValues(alpha: 0.10)
                        : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: active || focused ? _accent : Colors.transparent,
                    width: GuideChromeStyle.len(context, 3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _ChannelLogo(url: widget.channel.logoUrl ?? ''),
                      if (widget.health != null)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Builder(
                            builder: (context) {
                              final tv =
                                  ShellPaintScope.usesTvDensityOf(context);
                              final size =
                                  ShellTokens.chromeScale(8, tv: tv);
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.health! ? _alive : _dead,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: GuideChromeStyle.len(context, 12)),
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
                            fontSize: GuideChromeStyle.type(context, 12),
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
                              fontSize: GuideChromeStyle.type(context, 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (active)
                    Icon(
                      Icons.play_arrow_rounded,
                      color: _accent,
                      size: ShellPaintScope.iconOf(context, 18),
                    ),
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
    final w = GuideChromeStyle.len(context, width);
    final h = GuideChromeStyle.len(context, height);
    if (url.isEmpty) return _placeholder(context, w, h);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Only cacheWidth — both dims force a stretched decode.
    final cacheW = (w * dpr).round().clamp(1, 512);
    return SizedBox(
      width: w,
      height: h,
      child: ForjaNetworkImage(
        key: ValueKey(url),
        url: url,
        width: w,
        height: h,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        memCacheWidth: cacheW,
        filterQuality: FilterQuality.medium,
        useOldImageOnUrlChange: false,
        placeholder: _placeholder(context, w, h),
        error: _placeholder(context, w, h),
      ),
    );
  }

  Widget _placeholder(BuildContext context, double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Icon(
        Icons.live_tv_rounded,
        color: Colors.white38,
        size: h * 0.5,
      ),
    );
  }
}
