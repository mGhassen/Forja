import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/services/panel/kit_resolve_panel_host.dart';
import 'package:forja/shared/foundation/components/cards/kit_event_card.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_live_tv_browse.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/registry/kit_resolve_streams_hooks.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/foundation/tv/media_details_tv_scope.dart';
import 'package:forja/shared/foundation/components/hero/hero_pill_buttons.dart';
import 'package:forja/shared/foundation/components/details/kit_details_hero.dart';
import 'package:forja/shared/foundation/components/details/kit_details_play_row.dart';

/// Full-bleed live match details — [KitDetailsHero] + Providers / Live TV.
class KitMatchDetailsPage extends StatefulWidget {
  const KitMatchDetailsPage({
    super.key,
    required this.entry,
    this.refreshEpoch = 0,
  });

  final KitListEntry entry;
  final int refreshEpoch;

  @override
  State<KitMatchDetailsPage> createState() => _KitMatchDetailsPageState();
}

class _KitMatchDetailsPageState extends State<KitMatchDetailsPage> {
  static const _providers = KitResolvePanelHost.providersTab;
  static const _liveTv = KitResolvePanelHost.liveTvTab;

  final _backFocus = FocusNode(debugLabel: 'live-match-details-back');
  KitUrlHealthProbe? _healthProbe;
  late String _tabId;
  bool _streamsVisible = false;
  bool _heroFocusDone = false;
  String _liveTvChannelQuery = '';

  @override
  void initState() {
    super.initState();
    _tabId = _providers;
    // Old live details auto-opened Providers on land.
    _streamsVisible = true;
    final create = KitResolveStreamsHooks.createHealthProbe;
    _healthProbe = create?.call(
      onResult: (_, _) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _backFocus.dispose();
    _healthProbe?.dispose();
    super.dispose();
  }

  MatchEvent get _match => MatchEvent.fromLegacyRow(widget.entry.legacyRow);

  List<String> get _metaParts {
    final m = _match;
    final parts = <String>[];
    if (m.isLive) {
      parts.add('Live');
    } else {
      final t = kitEventTimeLabel(m);
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
      if (id != _liveTv) {
        _liveTvChannelQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final backdrop = kitEventImageUrl(m.poster);
    final viewport = MediaQuery.sizeOf(context);
    final title = m.title.trim().isEmpty ? widget.entry.meta.name : m.title;
    final probe = _healthProbe;
    final showLiveTvSearch = _streamsVisible && _tabId == _liveTv;

    if (policy.heroPlayAutoFocus && !_heroFocusDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _heroFocusDone) return;
        _heroFocusDone = true;
        if (_backFocus.canRequestFocus) _backFocus.requestFocus();
      });
    }

    Widget? streamsPanel;
    if (_streamsVisible) {
      Widget panelBuilder() => KitSourcesPanel(
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
            showInlineSearch: false,
            channelQuery: _tabId == _liveTv ? _liveTvChannelQuery : '',
            browseCategoryTabIds: const {_liveTv},
            loadTab: (tabId) => KitResolvePanelHost.loadTab(
              widget.entry.legacyRow,
              tabId,
              healthProbe: probe,
            ),
            onPlayRow: (row) => KitResolvePanelHost.playRow(
              context,
              row,
              title: title,
            ),
            tvTabId: MediaDetailsTv.tabId,
          );
      streamsPanel = probe == null
          ? panelBuilder()
          : ListenableBuilder(
              listenable: probe,
              builder: (context, _) => panelBuilder(),
            );
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
            actionRow: Align(
              alignment: Alignment.centerLeft,
              child: DetailsHeroTvActionScope(
                tabId: MediaDetailsTv.tabId,
                itemCount: 2,
                onFocusUp: tvFocus ? () => _backFocus.requestFocus() : null,
                onFocusDown: tvFocus ? () {} : null,
                child: Row(
                  children: [
                    Flexible(
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
                        onUpEdge:
                            tvFocus ? () => _backFocus.requestFocus() : null,
                        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                        tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                        tvItemIndexStart: 0,
                      ),
                    ),
                    if (showLiveTvSearch) ...[
                      const SizedBox(width: 10),
                      KitSourcesExpandingSearch(
                        query: _liveTvChannelQuery,
                        onQueryChanged: (q) {
                          if (q == _liveTvChannelQuery) return;
                          setState(() => _liveTvChannelQuery = q);
                        },
                        debugLabel: 'live-match-details-live-tv-search',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            belowActionRowFullWidth: true,
            belowActionRow: streamsPanel,
          ),
          MediaDetailsBackButton(focusNode: _backFocus),
        ],
      ),
    );
  }
}
