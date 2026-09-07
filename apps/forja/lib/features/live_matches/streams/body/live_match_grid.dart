part of '../live_sports_hub_page.dart';

mixin _LiveMatchesBuild on ConsumerState<LiveSportsHubPage> {
  _LiveSportsHubPageState get _s => this as _LiveSportsHubPageState;

  int cardViewersForMatch(_StreamedMatch match) {
    final cached = _s._eventStreamViewerTotals[_liveEventViewerKey(match)];
    if (cached != null && cached > 0) return cached;
    final inline = match.inlineStreams.fold<int>(
      0,
      (n, s) => n + (s.viewers > 0 ? s.viewers : 0),
    );
    if (inline > 0) return inline;
    if (!_s._mergeMatchingEvents) {
      return match.viewers;
    }
    final catalog = _catalogViewersForEvent(match, _s._streamedMatches);
    return catalog > 0 ? catalog : match.viewers;
  }

  @override
  Widget build(BuildContext context) {
    if (!_s.widget.panelOnly) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Live Sports browse is kit-owned. Use LiveSportsBrowseShell.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ForjaShellColors.textSecondary),
          ),
        ),
      );
    }
    final match = _s._streamsPanelMatch;
    if (match == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: ForjaShellColors.sectionAccent,
        ),
      );
    }
    return _LiveMatchStreamsPanel(
      host: _s,
      match: match,
      iframeCatalogAnchor: _s._streamsPanelIframeAnchor,
      asSidePanel: true,
    );
  }
}
