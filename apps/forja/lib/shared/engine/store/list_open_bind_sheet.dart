import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import 'package:google_fonts/google_fonts.dart';

/// Result of the single Open-in bind sheet.
class ListOpenBindResult {
  const ListOpenBindResult({
    required this.candidate,
    this.hit,
  });

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
  final FocusNode _queryFocus = FocusNode();
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
    _query = TextEditingController(text: widget.sourceMeta.name.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onHubReady();
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
    super.dispose();
  }

  void _selectHub(ListOpenCandidate hub) {
    if (_hub.pluginId == hub.pluginId) return;
    setState(() {
      _hub = hub;
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
      _hits = hits;
      _error = hits.isEmpty ? 'No matches in ${_hub.label}' : null;
    });
  }

  void _confirmCompatible() {
    Navigator.of(context).pop(ListOpenBindResult(candidate: _hub));
  }

  void _confirmHit(MetaItem hit) {
    Navigator.of(context).pop(
      ListOpenBindResult(candidate: _hub, hit: hit),
    );
  }

  bool _isBest(MetaItem hit, int index) {
    if (index != 0 || _hits.isEmpty) return false;
    final qYear = listOpenParseYear(_yearHint) ??
        listOpenParseYear(_query.text);
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
    final tv = policy.browseTextUntilActivate;
    final poster = widget.sourceMeta.poster.trim();
    final release = _yearHint;

    return Dialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 480,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: ForjaShellColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PosterThumb(url: poster),
                  const SizedBox(width: 12),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (release.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            release,
                            style: TextStyle(
                              color: ForjaShellColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Hub',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in widget.candidates)
                    ForjaShellChip(
                      label: c.label,
                      selected: c.pluginId == _hub.pluginId,
                      onTap: () => _selectHub(c),
                      loading: _searching && c.pluginId == _hub.pluginId,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_hub.compatible) ...[
                _CompatibleOpenBody(
                  hubLabel: _hub.label,
                  onOpen: _confirmCompatible,
                  tv: tv,
                ),
                const Spacer(),
              ] else ...[

                _SearchField(
                  controller: _query,
                  focusNode: _queryFocus,
                  tv: tv,
                  onChanged: (_) => _scheduleSearch(),
                  onSubmitted: (_) => _runSearch(),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _HitsBody(
                    searching: _searching,
                    error: _error,
                    hits: _hits,
                    isBest: _isBest,
                    onPick: _confirmHit,
                    tv: tv,
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
  const _PosterThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 52,
        height: 78,
        child: url.isEmpty
            ? ColoredBox(
                color: Colors.white.withValues(alpha: 0.06),
                child: Icon(
                  Icons.movie_outlined,
                  color: ForjaShellColors.iconMuted,
                  size: 22,
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
                    size: 20,
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
    required this.tv,
  });

  final String hubLabel;
  final VoidCallback onOpen;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: ForjaShellColors.brandGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ForjaShellColors.brandGreen.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: ForjaShellColors.brandGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Open in $hubLabel',
              style: GoogleFonts.plusJakartaSans(
                color: ForjaShellColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: ForjaShellColors.brandGreen),
        ],
      ),
    );
    if (tv) {
      return shellFocusableTap(
        context: context,
        onTap: onOpen,
        borderRadius: 10,
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.tv,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool tv;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  InputDecoration get _decoration => InputDecoration(
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
          size: tv
              ? ShellTokens.formInputIconSizeTv
              : ShellTokens.formInputIconSize,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ForjaShellColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ForjaShellColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
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

  @override
  Widget build(BuildContext context) {
    final fontSize = tv
        ? ShellTokens.formInputFontSizeTv
        : ShellTokens.formInputFontSize;
    final style = TextStyle(color: ForjaShellColors.textPrimary, fontSize: fontSize);
    if (tv) {
      return TvBrowseTextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: _decoration,
        style: style,
        browsePlaceholder: 'Search title — OK to type',
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      decoration: _decoration,
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
    required this.tv,
  });

  final bool searching;
  final String? error;
  final List<MetaItem> hits;
  final bool Function(MetaItem hit, int index) isBest;
  final ValueChanged<MetaItem> onPick;
  final bool tv;

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
      return Center(
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: ForjaShellColors.textSecondary, fontSize: 13),
        ),
      );
    }
    if (hits.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      itemCount: hits.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: ForjaShellColors.borderSubtle,
      ),
      itemBuilder: (context, i) {
        final hit = hits[i];
        final best = isBest(hit, i);
        final year = hit.releaseInfo.trim().isNotEmpty
            ? hit.releaseInfo.trim()
            : hit.premiereDate.trim();
        final row = Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _PosterThumb(url: hit.poster.trim()),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (best)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'Best match',
                          style: TextStyle(
                            color: ForjaShellColors.brandGreen,
                            fontSize: 10,
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
                        fontSize: 13,
                        fontWeight: best ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (year.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        year,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: row,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: row,
              );

        if (tv) {
          return shellFocusableTap(
            context: context,
            onTap: () => onPick(hit),
            borderRadius: 8,
            child: decorated,
          );
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onPick(hit),
            borderRadius: BorderRadius.circular(8),
            child: decorated,
          ),
        );
      },
    );
  }
}
