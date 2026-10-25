import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:forja_foundation/components/forja_image_cache.dart';
import 'package:flutter/material.dart' hide Checkbox;
import 'package:flutter/services.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/checkbox.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/engine/store/list_open_binding.dart';
import 'package:forja/shared/engine/store/list_open_picker.dart';
import 'package:forja/shared/engine/store/list_open_title_rank.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_list_status_button.dart';
import 'package:forja/shared/engine/runtime/kit/pack_tracker_mark.dart';
import 'package:forja_foundation/widgets/catalog/letter_link_mark.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// Open with rebind searches every hub that can search.
/// A compatible hub is not a pre-checked direct open.
@visibleForTesting
bool listOpenBindUsesHubSearch({
  required bool pickFilm,
  required bool compatible,
  required bool hasSearch,
}) {
  if (!hasSearch) return false;
  if (pickFilm) return true;
  return !compatible;
}

/// Result of the single Open-in bind sheet.
class ListOpenBindResult {
  const ListOpenBindResult({required this.candidate, this.hit});

  final ListOpenCandidate candidate;

  /// Set when the hub needed a title match; null for compatible direct open.
  final MetaItem? hit;
}

enum _ListOpenBindMode { openWith, simkl }

/// One sheet: Open with (hub) and optional Simkl TMDB link modes.
Future<ListOpenBindResult?> showListOpenBindSheet(
  BuildContext context, {
  required List<ListOpenCandidate> candidates,
  required MetaItem sourceMeta,
  String title = 'Open in…',
  String? initialPluginId,
  bool pickFilm = false,
  bool simklLinkEnabled = false,
  bool initialSimklMode = false,
  String? openHubLabel,
  ListOpenCandidate? simklSearchCandidate,
  bool hasSimklLink = false,
  ListFollowTarget? listPinTarget,
  String? knownListStatus,
  Future<bool> Function(ListOpenBindResult result)? onSave,
  Future<bool> Function(MetaItem hit)? onSimklSave,
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
          pickFilm: pickFilm,
          simklLinkEnabled: simklLinkEnabled,
          initialSimklMode: initialSimklMode,
          openHubLabel: openHubLabel,
          simklSearchCandidate: simklSearchCandidate,
          hasSimklLink: hasSimklLink,
          listPinTarget: listPinTarget,
          knownListStatus: knownListStatus,
          onSave: onSave,
          onSimklSave: onSimklSave,
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
    this.pickFilm = false,
    this.simklLinkEnabled = false,
    this.initialSimklMode = false,
    this.openHubLabel,
    this.simklSearchCandidate,
    this.hasSimklLink = false,
    this.listPinTarget,
    this.knownListStatus,
    this.onSave,
    this.onSimklSave,
  });

  final List<ListOpenCandidate> candidates;
  final MetaItem sourceMeta;
  final String title;
  final String? initialPluginId;

  /// Right-click rebind: search every hub, check a title to save it.
  final bool pickFilm;

  final bool simklLinkEnabled;
  final bool initialSimklMode;
  final String? openHubLabel;
  final ListOpenCandidate? simklSearchCandidate;
  final bool hasSimklLink;

  /// My List status pin (TV cards hide pin — change status here).
  final ListFollowTarget? listPinTarget;
  final String? knownListStatus;

  /// Save the checked title and stay on the sheet. Null pops and opens.
  final Future<bool> Function(ListOpenBindResult result)? onSave;

  /// Persist TMDB for Simkl only; stay on the sheet.
  final Future<bool> Function(MetaItem hit)? onSimklSave;

  @override
  State<_ListOpenBindSheet> createState() => _ListOpenBindSheetState();
}

class _ListOpenBindSheetState extends State<_ListOpenBindSheet> {
  late ListOpenCandidate _hub;
  late _ListOpenBindMode _mode;
  late bool _simklLinked;
  late final TextEditingController _query;
  late final List<FocusNode> _chipNodes;
  final FocusNode _queryFocus = FocusNode();
  final FocusNode _openFocus = FocusNode();
  final FocusNode _openWithBtnFocus = FocusNode();
  final FocusNode _simklBtnFocus = FocusNode();
  final FocusNode _listPinFocus = FocusNode();
  final List<FocusNode> _hitNodes = [];
  Timer? _debounce;
  int _searchGen = 0;
  bool _searching = false;
  List<MetaItem> _hits = const [];
  String? _error;
  String? _pickedKey;
  MetaItem? _preview;
  bool _closed = false;
  bool _saving = false;

  MetaItem get _headerMeta => _preview ?? widget.sourceMeta;

  bool get _simklMode =>
      _mode == _ListOpenBindMode.simkl &&
      widget.simklLinkEnabled &&
      widget.simklSearchCandidate != null;

  ListOpenCandidate get _activeHub =>
      _simklMode ? widget.simklSearchCandidate! : _hub;

  String get _yearHint {
    final r = widget.sourceMeta.releaseInfo.trim();
    if (r.isNotEmpty) return r;
    return widget.sourceMeta.premiereDate.trim();
  }

  String get _headerYear {
    final r = _headerMeta.releaseInfo.trim();
    if (r.isNotEmpty) return r;
    return _headerMeta.premiereDate.trim();
  }

  @override
  void initState() {
    super.initState();
    _hub = _pickInitialHub();
    _simklLinked = widget.hasSimklLink;
    _mode = widget.initialSimklMode && widget.simklLinkEnabled
        ? _ListOpenBindMode.simkl
        : _ListOpenBindMode.openWith;
    _chipNodes = List.generate(
      widget.candidates.length,
      (i) => FocusNode(debugLabel: 'list-open-hub-$i'),
    );
    _query = TextEditingController(text: widget.sourceMeta.name.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onHubReady();
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_simklMode) {
        _simklBtnFocus.requestFocus();
        return;
      }
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
    _openWithBtnFocus.dispose();
    _simklBtnFocus.dispose();
    _listPinFocus.dispose();
    for (final node in _chipNodes) {
      node.dispose();
    }
    for (final node in _hitNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _setMode(_ListOpenBindMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _pickedKey = null;
      _preview = null;
      _fitHitFocus(0);
      _hits = const [];
      _error = null;
      _searching = false;
    });
    _onHubReady();
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
    if (_simklMode) {
      _simklBtnFocus.requestFocus();
      return;
    }
    final i = widget.candidates.indexWhere((c) => c.pluginId == _hub.pluginId);
    if (i < 0 || i >= _chipNodes.length) return;
    _chipNodes[i].requestFocus();
  }

  bool get _hasListPin => widget.listPinTarget != null;

  void _focusModeIcons() {
    if (widget.simklLinkEnabled) {
      if (_simklMode) {
        _simklBtnFocus.requestFocus();
        return;
      }
      _openWithBtnFocus.requestFocus();
      return;
    }
    if (_hasListPin) {
      _listPinFocus.requestFocus();
    }
  }

  void _focusBelowModeIcons() {
    if (_simklMode) {
      _focusBelowHubs();
      return;
    }
    _focusSelectedChip();
  }

  void _focusRightOfSimkl() {
    if (_hasListPin) {
      _listPinFocus.requestFocus();
      return;
    }
    _openWithBtnFocus.requestFocus();
  }

  void _focusLeftOfOpenWith() {
    if (_hasListPin) {
      _listPinFocus.requestFocus();
      return;
    }
    if (widget.simklLinkEnabled) {
      _simklBtnFocus.requestFocus();
    }
  }

  bool get _usesSearch {
    if (_simklMode) return widget.simklSearchCandidate!.hasSearch;
    return listOpenBindUsesHubSearch(
      pickFilm: widget.pickFilm,
      compatible: _hub.compatible,
      hasSearch: _hub.hasSearch,
    );
  }

  /// Rebind on a hub that cannot search: the current title, unchecked.
  bool get _filmOnly =>
      !_simklMode && widget.pickFilm && _hub.compatible && !_hub.hasSearch;

  void _focusBelowHubs() {
    if (_usesSearch || widget.pickFilm) {
      if (_filmOnly) {
        _openFocus.requestFocus();
        return;
      }
      _queryFocus.requestFocus();
      return;
    }
    if (_hub.compatible) {
      _openFocus.requestFocus();
      return;
    }
    _queryFocus.requestFocus();
  }

  void _selectHub(ListOpenCandidate hub) {
    if (_hub.pluginId == hub.pluginId) return;
    setState(() {
      _mode = _ListOpenBindMode.openWith;
      _hub = hub;
      _pickedKey = null;
      _preview = null;
      _fitHitFocus(0);
      _hits = const [];
      _error = null;
      _searching = false;
    });
    _onHubReady();
  }

  void _onHubReady() {
    if (_filmOnly) {
      setState(() {
        _error = null;
        _hits = const [];
        _searching = false;
      });
      return;
    }
    final hub = _activeHub;
    if (!_usesSearch && hub.compatible && !widget.pickFilm && !_simklMode) {
      return;
    }
    if (!hub.hasSearch) {
      setState(() {
        _error = '${hub.label} has no search';
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
    if (!_usesSearch) return;
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
    final hub = _activeHub;
    final hits = await listOpenSearchHub(
      pluginId: hub.pluginId,
      query: q,
      yearHint: _yearHint,
    );
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _searching = false;
      _fitHitFocus(hits.length);
      _hits = hits;
      _error = hits.isEmpty ? 'No matches in ${hub.label}' : null;
    });
  }

  String _hitKey(MetaItem hit) {
    final id = hit.open?.id.trim() ?? '';
    return '$id|${hit.name}';
  }

  void _popResult(ListOpenBindResult result) {
    if (_closed) return;
    _closed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  Future<void> _savePick(ListOpenBindResult result, String key) async {
    if (_closed || _saving || _pickedKey == key) return;
    if (_simklMode) {
      final hit = result.hit;
      final save = widget.onSimklSave;
      if (hit == null || save == null) return;
      _saving = true;
      final ok = await save(hit);
      _saving = false;
      if (!mounted || !ok) return;
      setState(() {
        _pickedKey = key;
        _simklLinked = true;
        _preview = widget.sourceMeta;
      });
      return;
    }
    final save = widget.onSave;
    if (!widget.pickFilm || save == null) {
      setState(() => _pickedKey = key);
      _popResult(result);
      return;
    }
    _saving = true;
    final ok = await save(result);
    _saving = false;
    if (!mounted || !ok) return;
    setState(() {
      _pickedKey = key;
      _preview = result.hit ?? widget.sourceMeta;
    });
  }

  void _confirmCompatible() {
    unawaited(_savePick(ListOpenBindResult(candidate: _activeHub), 'source'));
  }

  void _confirmHit(MetaItem hit) {
    unawaited(
      _savePick(
        ListOpenBindResult(candidate: _activeHub, hit: hit),
        _hitKey(hit),
      ),
    );
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
    final poster = _headerMeta.poster.trim();
    final release = _headerYear;
    final screen = MediaQuery.sizeOf(context);
    double px(double desktop) =>
        density ? desktop * ShellTokens.tvChromeScale : desktop;
    double type(double desktop) =>
        density ? ShellTokens.tvTypeSize(desktop) : desktop;
    final sheetW = SettingsTokens.bindSheetWidthOf(context, screen.width);
    final sheetH = SettingsTokens.bindSheetHeightOf(context, screen.height);

    Widget sheet = Dialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      insetPadding: SettingsTokens.dialogInsetPaddingOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          SettingsTokens.dialogRadiusOf(context),
        ),
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
                      _simklMode ? 'Match on Simkl' : widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: ForjaShellColors.textPrimary,
                        fontSize: type(18),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Button(
                    variant: ButtonVariant.plainIcon,
                    size: ButtonSize.icon,
                    icon: Icons.close_rounded,
                    compact: true,
                    color: ForjaShellColors.iconMuted,
                    iconSize: px(18),
                    height: px(32),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
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
                          _headerMeta.name.trim().isEmpty
                              ? 'Untitled'
                              : _headerMeta.name.trim(),
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
                        if (widget.simklLinkEnabled || _hasListPin) ...[
                          SizedBox(height: px(8)),
                          Row(
                            children: [
                              if (widget.simklLinkEnabled) ...[
                                _ModeIcon(
                                  focusNode: _simklBtnFocus,
                                  selected: _simklMode,
                                  idleColor: _simklLinked
                                      ? ForjaShellColors.textPrimary
                                      : ForjaShellColors.iconMuted,
                                  tooltip: 'Match on Simkl',
                                  size: px(28),
                                  onTap: () =>
                                      _setMode(_ListOpenBindMode.simkl),
                                  onDownEdge: dpad
                                      ? _focusBelowModeIcons
                                      : null,
                                  onRightEdge: dpad ? _focusRightOfSimkl : null,
                                  onLeftEdge: dpad ? () {} : null,
                                  onUpEdge: dpad ? () {} : null,
                                  icon: (color) => LetterLinkMark(
                                    letter: 'S',
                                    linked: _simklLinked,
                                    size: px(20),
                                    image: const AssetImage(kSimklLogoAsset),
                                    color: color,
                                  ),
                                ),
                                SizedBox(width: px(6)),
                              ],
                              if (_hasListPin) ...[
                                KitListStatusButton.follow(
                                  followTarget: widget.listPinTarget!,
                                  knownStatus: widget.knownListStatus,
                                  excludeFromTvTraversal: false,
                                  noHoverScale: true,
                                  iconSize: px(20),
                                  focusNode: _listPinFocus,
                                  onUpEdge: dpad ? () {} : null,
                                  onDownEdge: dpad
                                      ? _focusBelowModeIcons
                                      : null,
                                  onLeftEdge: dpad
                                      ? () {
                                          if (widget.simklLinkEnabled) {
                                            _simklBtnFocus.requestFocus();
                                          }
                                        }
                                      : null,
                                  onRightEdge: dpad
                                      ? () {
                                          if (widget.simklLinkEnabled) {
                                            _openWithBtnFocus.requestFocus();
                                          }
                                        }
                                      : null,
                                ),
                                SizedBox(width: px(6)),
                              ],
                              if (widget.simklLinkEnabled)
                                _ModeIcon(
                                  focusNode: _openWithBtnFocus,
                                  selected: !_simklMode,
                                  idleColor: ForjaShellColors.iconMuted,
                                  tooltip: 'Open with',
                                  size: px(28),
                                  onTap: () =>
                                      _setMode(_ListOpenBindMode.openWith),
                                  onDownEdge: dpad
                                      ? _focusBelowModeIcons
                                      : null,
                                  onLeftEdge: dpad
                                      ? _focusLeftOfOpenWith
                                      : null,
                                  onRightEdge: dpad ? () {} : null,
                                  onUpEdge: dpad ? () {} : null,
                                  icon: (color) => Icon(
                                    Icons.link_rounded,
                                    size: px(20),
                                    color: color,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.link_rounded,
                                  size: px(16),
                                  color: ForjaShellColors.iconMuted,
                                ),
                              if (!_simklMode &&
                                  (widget.openHubLabel ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                SizedBox(width: px(8)),
                                Flexible(
                                  child: Text(
                                    widget.simklLinkEnabled
                                        ? widget.openHubLabel!.trim()
                                        : 'Open with ${widget.openHubLabel!.trim()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ForjaShellColors.textSecondary,
                                      fontSize: type(12),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ] else ...[
                          SizedBox(height: px(8)),
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: px(16),
                                color: ForjaShellColors.iconMuted,
                              ),
                              SizedBox(width: px(6)),
                              Flexible(
                                child: Text(
                                  (widget.openHubLabel ?? '').trim().isNotEmpty
                                      ? 'Open with ${widget.openHubLabel!.trim()}'
                                      : 'Open with…',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ForjaShellColors.textSecondary,
                                    fontSize: type(13),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (!_simklMode) ...[
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
                        selected:
                            widget.candidates[i].pluginId == _hub.pluginId,
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
                        onUpEdge: dpad
                            ? (widget.simklLinkEnabled || _hasListPin
                                  ? _focusModeIcons
                                  : () {})
                            : null,
                      ),
                  ],
                ),
              ] else ...[
                SizedBox(height: px(14)),
                Text(
                  'Search ${widget.simklSearchCandidate!.label} for the Simkl title',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: type(11),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
              SizedBox(height: px(14)),
              if (_filmOnly) ...[
                _FilmCheckRow(
                  meta: widget.sourceMeta,
                  checked: _pickedKey == 'source',
                  onPick: _confirmCompatible,
                  dpad: dpad,
                  density: density,
                  focusNode: _openFocus,
                  onUp: _focusSelectedChip,
                ),
                const Spacer(),
              ] else if (!_simklMode &&
                  _hub.compatible &&
                  !widget.pickFilm) ...[
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
                          if (!shellTvIsNavigationKey(event)) {
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
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
                    pickFilm: widget.pickFilm || _simklMode,
                    pickedKey: _pickedKey,
                    hitKey: _hitKey,
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
    if (!dpad) return sheet;
    return ShellTvContainDpad(child: ShellTvLinearFocusScope(child: sheet));
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
                cacheManager: ForjaImageCacheManager(),
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

class _FilmCheckRow extends StatelessWidget {
  const _FilmCheckRow({
    required this.meta,
    required this.checked,
    required this.onPick,
    required this.dpad,
    required this.density,
    required this.focusNode,
    required this.onUp,
  });

  final MetaItem meta;
  final bool checked;
  final VoidCallback onPick;
  final bool dpad;
  final bool density;
  final FocusNode focusNode;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    double px(double desktop) =>
        density ? desktop * ShellTokens.tvChromeScale : desktop;
    double type(double desktop) =>
        density ? ShellTokens.tvTypeSize(desktop) : desktop;
    final year = meta.releaseInfo.trim().isNotEmpty
        ? meta.releaseInfo.trim()
        : meta.premiereDate.trim();
    final name = meta.name.trim().isEmpty ? 'Untitled' : meta.name.trim();
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: px(8), horizontal: px(6)),
      child: Row(
        children: [
          _PosterThumb(url: meta.poster.trim(), density: density),
          SizedBox(width: px(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ForjaShellColors.textPrimary,
                    fontSize: type(13),
                    fontWeight: FontWeight.w600,
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
          Checkbox(
            value: checked,
            onChanged: (v) {
              if (v == true) onPick();
            },
          ),
        ],
      ),
    );
    if (dpad) {
      return shellFocusableTap(
        context: context,
        onTap: onPick,
        borderRadius: px(8),
        focusNode: focusNode,
        scaleOnFocus: 1,
        showFocusBorder: true,
        onUpEdge: onUp,
        onDownEdge: () {},
        onLeftEdge: () {},
        onRightEdge: () {},
        child: row,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(px(8)),
        child: row,
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
    this.pickFilm = false,
    this.pickedKey,
    this.hitKey,
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
  final bool pickFilm;
  final String? pickedKey;
  final String Function(MetaItem hit)? hitKey;

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

    Widget hitTile(int i) {
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
            pickFilm
                ? Checkbox(
                    value: pickedKey != null && pickedKey == hitKey?.call(hit),
                    onChanged: (v) {
                      if (v == true) onPick(hit);
                    },
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    size: ShellPaintScope.iconOf(context, 20),
                    color: best
                        ? ForjaShellColors.brandGreen
                        : ForjaShellColors.iconMuted,
                  ),
          ],
        ),
      );

      final checked =
          pickFilm && pickedKey != null && pickedKey == hitKey?.call(hit);
      final decorated = (best && !pickFilm) || checked
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
        // Vertical ↑/↓: ShellTvLinearFocusScope. Keep all hit nodes mounted
        // (Column, not ListView) so ↑ never no-ops on a recycled FocusNode.
        return shellFocusableTap(
          context: context,
          onTap: () => onPick(hit),
          borderRadius: px(8),
          focusNode: focusNodes[i],
          scaleOnFocus: 1,
          showFocusBorder: true,
          ensureVisibleMode: ShellPaintEnsureVisible.item,
          onUpEdge: i == 0 ? onUpFromFirst : null,
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
    }

    if (dpad) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < hits.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: ForjaShellColors.borderSubtle),
              hitTile(i),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: hits.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: ForjaShellColors.borderSubtle),
      itemBuilder: (_, i) => hitTile(i),
    );
  }
}

/// Icon-only mode hit — color to green on select/focus/hover; no circle, no scale.
class _ModeIcon extends StatefulWidget {
  const _ModeIcon({
    required this.selected,
    required this.idleColor,
    required this.onTap,
    required this.tooltip,
    required this.size,
    required this.icon,
    this.focusNode,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final bool selected;
  final Color idleColor;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final Widget Function(Color color) icon;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_ModeIcon> createState() => _ModeIconState();
}

class _ModeIconState extends State<_ModeIcon> {
  bool _focused = false;
  bool _hovered = false;

  Color get _color {
    if (widget.selected || _focused || _hovered) {
      return ForjaShellColors.brandGreen;
    }
    return widget.idleColor;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: shellFocusableTap(
        context: context,
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        borderRadius: widget.size / 2,
        scaleOnFocus: 1,
        suppressInkHover: true,
        showFocusBorder: false,
        onFocusChange: (f) {
          if (_focused == f) return;
          setState(() => _focused = f);
        },
        onHoverChange: (h) {
          if (_hovered == h) return;
          setState(() => _hovered = h);
        },
        onUpEdge: widget.onUpEdge,
        onDownEdge: widget.onDownEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: widget.icon(_color)),
        ),
      ),
    );
  }
}
