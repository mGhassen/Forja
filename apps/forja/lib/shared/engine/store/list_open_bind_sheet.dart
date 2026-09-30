import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/store/list_open_binding.dart';
import 'package:forja/shared/engine/store/list_open_picker.dart';
import 'package:forja/shared/engine/store/list_open_title_rank.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// Result of the single Open-in bind sheet.
class ListOpenBindResult {
  const ListOpenBindResult({required this.candidate, this.hit});

  final ListOpenCandidate candidate;

  /// Set when the hub needed a title match; null for compatible direct open.
  final MetaItem? hit;
}

/// One sheet: hub chips + optional title search + ranked hits.
Future<ListOpenBindResult?> showListOpenBindSheet(
  BuildContext context, {
  required List<ListOpenCandidate> candidates,
  required MetaItem sourceMeta,
  String title = 'Open in…',
  String? initialPluginId,
}) {
  if (candidates.isEmpty) return Future.value(null);
  return showDialog<ListOpenBindResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return ShellScope.rehost(
        context,
        _ListOpenBindSheet(
          candidates: candidates,
          sourceMeta: sourceMeta,
          title: title,
          initialPluginId: initialPluginId,
        ),
      );
    },
  );
}

class _ListOpenBindSheet extends StatefulWidget {
  const _ListOpenBindSheet({
    required this.candidates,
    required this.sourceMeta,
    required this.title,
    this.initialPluginId,
  });

  final List<ListOpenCandidate> candidates;
  final MetaItem sourceMeta;
  final String title;
  final String? initialPluginId;

  @override
  State<_ListOpenBindSheet> createState() => _ListOpenBindSheetState();
}

class _ListOpenBindSheetState extends State<_ListOpenBindSheet> {
  late ListOpenCandidate _hub;
  late final TextEditingController _query;
  late final List<FocusNode> _chipNodes;
  final FocusNode _queryFocus = FocusNode();
  final FocusNode _openFocus = FocusNode();
  final List<FocusNode> _hitNodes = [];
  Timer? _debounce;
  int _searchGen = 0;
  bool _searching = false;
  List<MetaItem> _hits = const [];
  String? _error;

  String get _yearHint {
    final r = widget.sourceMeta.releaseInfo.trim();
    if (r.isNotEmpty) return r;
    return widget.sourceMeta.premiereDate.trim();
  }

  @override
  void initState() {
    super.initState();
    _hub = _pickInitialHub();
    _chipNodes = List.generate(
      widget.candidates.length,
      (i) => FocusNode(debugLabel: 'list-open-hub-$i'),
    );
    _query = TextEditingController(text: widget.sourceMeta.name.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onHubReady();
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      final i = widget.candidates.indexWhere(
        (c) => c.pluginId == _hub.pluginId,
      );
      if (i >= 0) _chipNodes[i].requestFocus();
    });
  }

  ListOpenCandidate _pickInitialHub() {
    final want = widget.initialPluginId?.trim() ?? '';
    if (want.isNotEmpty) {
      for (final c in widget.candidates) {
        if (c.pluginId == want) return c;
      }
    }
    for (final c in widget.candidates) {
      if (c.compatible) return c;
    }
    return widget.candidates.first;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    _openFocus.dispose();
    for (final node in _chipNodes) {
      node.dispose();
    }
    for (final node in _hitNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _fitHitFocus(int count) {
    while (_hitNodes.length > count) {
      _hitNodes.removeLast().dispose();
    }
    while (_hitNodes.length < count) {
      _hitNodes.add(FocusNode(debugLabel: 'list-open-hit-${_hitNodes.length}'));
    }
  }

  void _focusSelectedChip() {
    final i = widget.candidates.indexWhere((c) => c.pluginId == _hub.pluginId);
    if (i < 0 || i >= _chipNodes.length) return;
    _chipNodes[i].requestFocus();
  }

  void _focusBelowHubs() {
    if (_hub.compatible) {
      _openFocus.requestFocus();
      return;
    }
    _queryFocus.requestFocus();
  }

  void _selectHub(ListOpenCandidate hub) {
    if (_hub.pluginId == hub.pluginId) return;
    setState(() {
      _hub = hub;
      _fitHitFocus(0);
      _hits = const [];
      _error = null;
      _searching = false;
    });
    _onHubReady();
  }

  void _onHubReady() {
    if (_hub.compatible) return;
    if (!_hub.hasSearch) {
      setState(() {
        _error = '${_hub.label} has no search';
        _hits = const [];
      });
      return;
    }
    _runSearch();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _runSearch);
  }

  Future<void> _runSearch() async {
    if (_hub.compatible || !_hub.hasSearch) return;
    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() {
        _fitHitFocus(0);
        _hits = const [];
        _searching = false;
        _error = 'Type a title to search';
      });
      return;
    }
    final gen = ++_searchGen;
    setState(() {
      _searching = true;
      _error = null;
    });
    final hits = await listOpenSearchHub(
      pluginId: _hub.pluginId,
      query: q,
      yearHint: _yearHint,
    );
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _searching = false;
      _fitHitFocus(hits.length);
      _hits = hits;
      _error = hits.isEmpty ? 'No matches in ${_hub.label}' : null;
    });
  }

  void _confirmCompatible() {
    Navigator.of(context).pop(ListOpenBindResult(candidate: _hub));
  }

  void _confirmHit(MetaItem hit) {
    Navigator.of(context).pop(ListOpenBindResult(candidate: _hub, hit: hit));
  }

  bool _isBest(MetaItem hit, int index) {
    if (index != 0 || _hits.isEmpty) return false;
    final qYear =
        listOpenParseYear(_yearHint) ?? listOpenParseYear(_query.text);
    final hYear = listOpenParseYear(
      hit.releaseInfo.isNotEmpty ? hit.releaseInfo : hit.premiereDate,
    );
    return listOpenIsStrongTitleMatch(
          _query.text,
          hit.name,
          queryYear: qYear,
          candidateYear: hYear,
        ) ||
        listOpenTitleScore(
              _query.text,
              hit.name,
              queryYear: qYear,
              candidateYear: hYear,
            ) >=
            800;
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final density = ShellScope.metricsOf(context).usesTvDensity;
    final leanback = policy.browseTextUntilActivate;
    final dpad = policy.useFocusableMoodChips;
    final poster = widget.sourceMeta.poster.trim();
    final release = _yearHint;
    final screen = MediaQuery.sizeOf(context);
    double px(double desktop) =>
        density ? desktop * ShellTokens.tvChromeScale : desktop;
    double type(double desktop) =>
        density ? ShellTokens.tvTypeSize(desktop) : desktop;
    final sheetW = density ? (screen.width * 0.34).clamp(240.0, 360.0) : 480.0;
    final sheetH = density ? (screen.height * 0.58).clamp(280.0, 420.0) : 560.0;

    return Dialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      insetPadding: EdgeInsets.symmetric(horizontal: px(24), vertical: px(24)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(px(14)),
      ),
      child: SizedBox(
        width: sheetW,
        height: sheetH,
        child: Padding(
          padding: EdgeInsets.fromLTRB(px(18), px(16), px(18), px(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: ForjaShellColors.textPrimary,
                        fontSize: type(18),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.symmetric(
                        horizontal: px(8),
                        vertical: px(4),
                      ),
                      minimumSize: Size(px(48), px(28)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: type(14),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: px(12)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PosterThumb(url: poster, density: density),
                  SizedBox(width: px(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sourceMeta.name.trim().isEmpty
                              ? 'Untitled'
                              : widget.sourceMeta.name.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: ForjaShellColors.textPrimary,
                            fontSize: type(15),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (release.isNotEmpty) ...[
                          SizedBox(height: px(4)),
                          Text(
                            release,
                            style: TextStyle(
                              color: ForjaShellColors.textSecondary,
                              fontSize: type(12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: px(14)),
              Text(
                'Hub',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: type(11),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: px(8)),
              Wrap(
                spacing: px(8),
                runSpacing: px(8),
                children: [
                  for (var i = 0; i < widget.candidates.length; i++)
                    ForjaShellChip(
                      label: widget.candidates[i].label,
                      selected: widget.candidates[i].pluginId == _hub.pluginId,
                      focusNode: _chipNodes[i],
                      onTap: () => _selectHub(widget.candidates[i]),
                      loading:
                          _searching &&
                          widget.candidates[i].pluginId == _hub.pluginId,
                      onLeftEdge: !dpad
                          ? null
                          : i == 0
                          ? () {}
                          : () => _chipNodes[i - 1].requestFocus(),
                      onRightEdge: !dpad
                          ? null
                          : i == widget.candidates.length - 1
                          ? () {}
                          : () => _chipNodes[i + 1].requestFocus(),
                      onDownEdge: dpad ? _focusBelowHubs : null,
                      onUpEdge: dpad ? () {} : null,
                    ),
                ],
              ),
              SizedBox(height: px(14)),
              if (_hub.compatible) ...[
                _CompatibleOpenBody(
                  hubLabel: _hub.label,
                  onOpen: _confirmCompatible,
                  dpad: dpad,
                  density: density,
                  focusNode: _openFocus,
                  onUp: _focusSelectedChip,
                ),
                const Spacer(),
              ] else ...[
                _SearchField(
                  controller: _query,
                  focusNode: _queryFocus,
                  leanback: leanback,
                  density: density,
                  onChanged: (_) => _scheduleSearch(),
                  onSubmitted: (_) => _runSearch(),
                  onKeyEvent: dpad
                      ? (node, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                            if (_hitNodes.isEmpty) {
                              return KeyEventResult.ignored;
                            }
                            _hitNodes.first.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _focusSelectedChip();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        }
                      : null,
                ),
                SizedBox(height: px(10)),
                Expanded(
                  child: _HitsBody(
                    searching: _searching,
                    error: _error,
                    hits: _hits,
                    isBest: _isBest,
                    onPick: _confirmHit,
                    dpad: dpad,
                    density: density,
                    focusNodes: _hitNodes,
                    onUpFromFirst: () => _queryFocus.requestFocus(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterThumb extends StatelessWidget {
  const _PosterThumb({required this.url, this.density = false});

  final String url;
  final bool density;

  @override
  Widget build(BuildContext context) {
    final w = density ? 52 * ShellTokens.tvChromeScale : 52.0;
    final h = density ? 78 * ShellTokens.tvChromeScale : 78.0;
    final radius = density ? 8 * ShellTokens.tvChromeScale : 8.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: w,
        height: h,
        child: url.isEmpty
            ? ColoredBox(
                color: Colors.white.withValues(alpha: 0.06),
                child: Icon(
                  Icons.movie_outlined,
                  color: ForjaShellColors.iconMuted,
                  size: ShellPaintScope.iconOf(context, 22),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => ColoredBox(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: ForjaShellColors.iconMuted,
                    size: ShellPaintScope.iconOf(context, 20),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CompatibleOpenBody extends StatelessWidget {
  const _CompatibleOpenBody({
    required this.hubLabel,
    required this.onOpen,
    required this.dpad,
    required this.density,
    required this.focusNode,
    required this.onUp,
  });

  final String hubLabel;
  final VoidCallback onOpen;
  final bool dpad;
  final bool density;
  final FocusNode focusNode;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    double px(double desktop) =>
        density ? desktop * ShellTokens.tvChromeScale : desktop;
    final type = density ? ShellTokens.tvTypeSize(14) : 14.0;
    final radius = px(10);
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: px(14), vertical: px(10)),
      decoration: BoxDecoration(
        color: ForjaShellColors.brandGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: ForjaShellColors.brandGreen.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: ForjaShellColors.brandGreen,
            size: ShellPaintScope.iconOf(context, 20),
          ),
          SizedBox(width: px(10)),
          Expanded(
            child: Text(
              'Open in $hubLabel',
              style: GoogleFonts.plusJakartaSans(
                color: ForjaShellColors.textPrimary,
                fontSize: type,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: ForjaShellColors.brandGreen,
            size: ShellPaintScope.iconOf(context, 20),
          ),
        ],
      ),
    );
    if (dpad) {
      return shellFocusableTap(
        context: context,
        onTap: onOpen,
        borderRadius: radius,
        focusNode: focusNode,
        scaleOnFocus: 1,
        showFocusBorder: true,
        onUpEdge: onUp,
        onDownEdge: () {},
        onLeftEdge: () {},
        onRightEdge: () {},
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.leanback,
    required this.density,
    required this.onChanged,
    required this.onSubmitted,
    this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool leanback;
  final bool density;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final tv = density;
    final fontSize = tv
        ? ShellTokens.formInputFontSizeTv
        : ShellTokens.formInputFontSize;
    final icon = tv
        ? ShellTokens.formInputIconSizeTv
        : ShellTokens.formInputIconSize;
    final slot = tv ? ShellTokens.controlHeightTv : 40.0;
    final style = TextStyle(
      color: ForjaShellColors.textPrimary,
      fontSize: fontSize,
    );
    final decoration = InputDecoration(
      hintText: 'Search title',
      hintStyle: TextStyle(
        color: ForjaShellColors.textSecondary,
        fontSize: tv
            ? ShellTokens.formInputHintFontSizeTv
            : ShellTokens.formInputHintFontSize,
      ),
      prefixIcon: Icon(
        Icons.search,
        color: ForjaShellColors.iconMuted,
        size: icon,
      ),
      prefixIconConstraints: BoxConstraints(
        minWidth: slot,
        maxWidth: slot,
        minHeight: slot,
        maxHeight: slot,
      ),
      isCollapsed: false,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tv ? 8 : 10),
        borderSide: BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tv ? 8 : 10),
        borderSide: BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tv ? 8 : 10),
        borderSide: BorderSide(color: ForjaShellColors.brandGreen),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tv
            ? ShellTokens.formInputPadHSmTv
            : ShellTokens.formInputPadHSm,
        vertical: tv
            ? ShellTokens.formInputPadVSmTv
            : ShellTokens.formInputPadVSm,
      ),
      isDense: true,
    );
    if (leanback) {
      return TvBrowseTextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onKeyEvent: onKeyEvent,
        decoration: decoration,
        style: style,
        browsePlaceholder: 'Search title — OK to type',
        caretHeight: fontSize,
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      decoration: decoration,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _HitsBody extends StatelessWidget {
  const _HitsBody({
    required this.searching,
    required this.error,
    required this.hits,
    required this.isBest,
    required this.onPick,
    required this.dpad,
    required this.density,
    required this.focusNodes,
    required this.onUpFromFirst,
  });

  final bool searching;
  final String? error;
  final List<MetaItem> hits;
  final bool Function(MetaItem hit, int index) isBest;
  final ValueChanged<MetaItem> onPick;
  final bool dpad;
  final bool density;
  final List<FocusNode> focusNodes;
  final VoidCallback onUpFromFirst;

  @override
  Widget build(BuildContext context) {
    if (searching && hits.isEmpty) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ForjaShellColors.brandGreen,
          ),
        ),
      );
    }
    if (error != null && hits.isEmpty) {
      final type = density ? ShellTokens.tvTypeSize(13) : 13.0;
      return Center(
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: type,
          ),
        ),
      );
    }
    if (hits.isEmpty) {
      return const SizedBox.shrink();
    }

    double px(double desktop) =>
        density ? desktop * ShellTokens.tvChromeScale : desktop;
    double type(double desktop) =>
        density ? ShellTokens.tvTypeSize(desktop) : desktop;

    return ListView.separated(
      itemCount: hits.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: ForjaShellColors.borderSubtle),
      itemBuilder: (context, i) {
        final hit = hits[i];
        final best = isBest(hit, i);
        final year = hit.releaseInfo.trim().isNotEmpty
            ? hit.releaseInfo.trim()
            : hit.premiereDate.trim();
        final row = Padding(
          padding: EdgeInsets.symmetric(vertical: px(8)),
          child: Row(
            children: [
              _PosterThumb(url: hit.poster.trim(), density: density),
              SizedBox(width: px(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (best)
                      Padding(
                        padding: EdgeInsets.only(bottom: px(2)),
                        child: Text(
                          'Best match',
                          style: TextStyle(
                            color: ForjaShellColors.brandGreen,
                            fontSize: type(10),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    Text(
                      hit.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: ForjaShellColors.textPrimary,
                        fontSize: type(13),
                        fontWeight: best ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (year.isNotEmpty) ...[
                      SizedBox(height: px(2)),
                      Text(
                        year,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: type(11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: ShellPaintScope.iconOf(context, 20),
                color: best
                    ? ForjaShellColors.brandGreen
                    : ForjaShellColors.iconMuted,
              ),
            ],
          ),
        );

        final decorated = best
            ? Container(
                decoration: BoxDecoration(
                  color: ForjaShellColors.brandGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(px(8)),
                ),
                padding: EdgeInsets.symmetric(horizontal: px(6)),
                child: row,
              )
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: px(6)),
                child: row,
              );

        if (dpad && i < focusNodes.length) {
          return shellFocusableTap(
            context: context,
            onTap: () => onPick(hit),
            borderRadius: px(8),
            focusNode: focusNodes[i],
            scaleOnFocus: 1,
            showFocusBorder: true,
            onUpEdge: i == 0
                ? onUpFromFirst
                : () => focusNodes[i - 1].requestFocus(),
            onDownEdge: i == hits.length - 1
                ? () {}
                : () => focusNodes[i + 1].requestFocus(),
            onLeftEdge: () {},
            onRightEdge: () {},
            child: decorated,
          );
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onPick(hit),
            borderRadius: BorderRadius.circular(px(8)),
            child: decorated,
          ),
        );
      },
    );
  }
}
