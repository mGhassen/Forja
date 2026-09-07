import 'package:flutter/material.dart';
import 'package:forja/features/live_sports/catalog/live_sports_streams_panel_host.dart';
import 'package:forja/shared/foundation/components/cards/live_match_card.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/kit_details/kit_details_hero.dart';
import 'package:forja/shared/widgets/kit_details/kit_details_play_row.dart';

/// Full-bleed live match details — [KitDetailsHero] + Providers / Live TV.
///
/// Restores the pre-kit cards-pack details chrome (not a panel-in-scaffold).
class LiveMatchDetailsPage extends StatefulWidget {
  const LiveMatchDetailsPage({
    super.key,
    required this.entry,
    this.refreshEpoch = 0,
  });

  final KitListEntry entry;
  final int refreshEpoch;

  @override
  State<LiveMatchDetailsPage> createState() => _LiveMatchDetailsPageState();
}

class _LiveMatchDetailsPageState extends State<LiveMatchDetailsPage> {
  static const _providers = LiveSportsStreamsPanelHost.providersTab;
  static const _liveTv = LiveSportsStreamsPanelHost.liveTvTab;

  final _backFocus = FocusNode(debugLabel: 'live-match-details-back');
  late String _tabId;
  bool _streamsVisible = false;
  bool _heroFocusDone = false;

  @override
  void initState() {
    super.initState();
    _tabId = _providers;
  }

  @override
  void dispose() {
    _backFocus.dispose();
    super.dispose();
  }

  MatchEvent get _match => MatchEvent.fromLegacyRow(widget.entry.legacyRow);

  List<String> get _metaParts {
    final m = _match;
    final parts = <String>[];
    if (m.isLive) {
      parts.add('Live');
    } else {
      final t = liveMatchTimeLabel(m);
      if (t.isNotEmpty) parts.add(t);
    }
    if (m.viewers > 0) parts.add('${m.viewers} viewers');
    return parts;
  }

  void _selectTab(String id) {
    if (_tabId == id && _streamsVisible) return;
    setState(() {
      _tabId = id;
      _streamsVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final backdrop = liveMatchImageUrl(m.poster);
    final viewport = MediaQuery.sizeOf(context);
    final title = m.title.trim().isEmpty ? widget.entry.meta.name : m.title;

    if (policy.heroPlayAutoFocus && !_heroFocusDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _heroFocusDone) return;
        _heroFocusDone = true;
        if (_backFocus.canRequestFocus) _backFocus.requestFocus();
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          KitDetailsHero(
            backdropUrl: backdrop,
            title: title,
            subtitle: m.categoryLabel,
            genres: const [],
            metaParts: _metaParts,
            overview: '',
            height: viewport.height,
            actionRow: DetailsHeroTvActionScope(
              tabId: MediaDetailsTv.tabId,
              itemCount: 2,
              onFocusUp: tvFocus ? () => _backFocus.requestFocus() : null,
              onFocusDown: tvFocus ? () {} : null,
              child: HeroPillSegmentedChoice<String>(
                segments: const [
                  HeroPillSegment(
                    value: _providers,
                    label: 'Providers',
                    icon: Icons.dns_rounded,
                  ),
                  HeroPillSegment(
                    value: _liveTv,
                    label: 'Live TV',
                    icon: Icons.live_tv_rounded,
                  ),
                ],
                selected: _tabId,
                onSelected: _selectTab,
                onUpEdge: tvFocus ? () => _backFocus.requestFocus() : null,
                tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                tvItemIndexStart: 0,
              ),
            ),
            belowActionRowFullWidth: true,
            belowActionRow: _streamsVisible
                ? KitSourcesPanel(
                    key: ValueKey(
                      'live-details-${widget.entry.meta.id}-$_tabId-${widget.refreshEpoch}',
                    ),
                    title: title,
                    subtitle: m.categoryLabel,
                    embedded: true,
                    tabs: const [
                      KitSourcesTab(id: _providers, label: 'Providers'),
                      KitSourcesTab(id: _liveTv, label: 'Live TV'),
                    ],
                    initialTabId: _tabId,
                    showTabs: false,
                    loadTab: (tabId) => LiveSportsStreamsPanelHost.loadTab(
                      widget.entry.legacyRow,
                      tabId,
                    ),
                    onPlayRow: (row) => LiveSportsStreamsPanelHost.playRow(
                      context,
                      row,
                      title: title,
                    ),
                    tvTabId: MediaDetailsTv.tabId,
                  )
                : null,
          ),
          MediaDetailsBackButton(focusNode: _backFocus),
        ],
      ),
    );
  }
}
