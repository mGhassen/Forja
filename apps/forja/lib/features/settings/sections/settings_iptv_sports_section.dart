import 'package:flutter/material.dart';
import 'package:forja/features/iptv/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/live_matches/live_matches_iptv_sports_settings.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';

/// Settings → My IPTV sports — Live Matches Xtream matcher (RFC-062).
class SettingsIptvSportsSection extends StatefulWidget {
  const SettingsIptvSportsSection({super.key});

  @override
  State<SettingsIptvSportsSection> createState() =>
      _SettingsIptvSportsSectionState();
}

class _SettingsIptvSportsSectionState extends State<SettingsIptvSportsSection> {
  LiveMatchesIptvSportsConfig _config = const LiveMatchesIptvSportsConfig();
  List<VerifiedPortal> _portals = const [];
  List<IptvCategory> _liveCategories = const [];
  bool _loading = true;
  bool _loadingCats = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await LiveMatchesIptvSportsConfig.load();
      final all = await IptvStore.load();
      final portals = all
          .where((p) => p.portal.platform == IptvPortalPlatform.xtream)
          .toList();
      final portalKey =
          await LiveMatchesIptvSportsConfig.resolvePortalKey(config);
      if (!mounted) return;
      setState(() {
        _config = config;
        _portals = portals;
        _loading = false;
      });
      if (portalKey.isNotEmpty) {
        await _loadCategoriesFor(portalKey);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _persist(LiveMatchesIptvSportsConfig next) async {
    setState(() => _config = next);
    await LiveMatchesIptvSportsConfig.save(next);
  }

  Future<void> _loadCategoriesFor(String portalKey) async {
    VerifiedPortal? portal;
    for (final p in _portals) {
      if (p.key == portalKey) {
        portal = p;
        break;
      }
    }
    if (portal == null) {
      setState(() => _liveCategories = const []);
      return;
    }
    setState(() => _loadingCats = true);
    try {
      final disk = await IptvCatalogDiskStore.load(
        portal.key,
        IptvSection.live,
      );
      if (disk != null && disk.categories.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _liveCategories = disk.categories;
          _loadingCats = false;
        });
        return;
      }
      final fetch = await IptvClient.catalog(portal.portal, IptvSection.live);
      if (!mounted) return;
      setState(() {
        _liveCategories = fetch.categories;
        _loadingCats = false;
        if (!fetch.ok) {
          _error = fetch.error ?? 'Failed to load live categories';
        }
      });
      if (fetch.ok) {
        await IptvCatalogDiskStore.save(
          portal.key,
          IptvSection.live,
          fetch.categories,
          fetch.streams,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCats = false;
        _error = '$e';
      });
    }
  }

  Future<void> _toggleLeague(String league) async {
    final next = List<String>.from(_config.leagues);
    if (next.contains(league)) {
      next.remove(league);
    } else {
      next.add(league);
    }
    await _persist(_config.copyWith(leagues: next));
  }

  Future<void> _editCategories(String familyKey) async {
    if (_liveCategories.isEmpty) {
      ForjaToast.info('Load live categories from the portal first');
      return;
    }
    final selected = Set<String>.from(
      _config.sportCategories[familyKey] ?? const [],
    );
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ForjaShellColors.surfaceElevated,
      builder: (ctx) {
        return _CategoryMultiPickSheet(
          title: LiveMatchesIptvSportsConfig.sportFamilyLabels[familyKey] ??
              familyKey,
          categories: _liveCategories,
          initiallySelected: selected,
        );
      },
    );
    if (result == null || !mounted) return;
    final map = Map<String, List<String>>.from(_config.sportCategories);
    if (result.isEmpty) {
      map.remove(familyKey);
    } else {
      map[familyKey] = result.toList()..sort();
    }
    await _persist(_config.copyWith(sportCategories: map));
  }

  String _categorySubtitle(String key) {
    final ids = _config.sportCategories[key] ?? const [];
    if (ids.isEmpty) return 'All live channels (default)';
    final names = <String>[];
    for (final id in ids) {
      String? name;
      for (final c in _liveCategories) {
        if (c.id == id) {
          name = c.name;
          break;
        }
      }
      names.add(name ?? id);
    }
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SettingsGroup(
        label: 'My IPTV sports',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }

    return SettingsGroup(
      label: 'Setup',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
          child: Text(
            'Pick the portal in Live Matches → My IPTV (top-right Portals). '
            'Here: leagues and optional folder narrowing.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFF87171),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        SettingsToggleRow(
          title: 'Enable My IPTV',
          subtitle: 'Show the My IPTV server in Live Matches',
          value: _config.enabled,
          onChanged: (v) async {
            var next = _config.copyWith(enabled: v);
            // First enable with no leagues → select all (don't force chip spam).
            if (v && next.leagues.isEmpty) {
              next = next.copyWith(
                leagues: List<String>.from(LiveMatchesIptvSportsConfig.allLeagues),
              );
            }
            // Seed portal from IPTV’s last Xtream selection (no Settings picker).
            if (v && next.portalKey.isEmpty) {
              final fromIptv =
                  await LiveMatchesIptvSportsConfig.resolvePortalKey(next);
              if (fromIptv.isNotEmpty) {
                next = next.copyWith(portalKey: fromIptv);
              }
            }
            await _persist(next);
            if (v && next.portalKey.isNotEmpty) {
              await _loadCategoriesFor(next.portalKey);
            }
          },
        ),
        if (_loadingCats)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Leagues',
                  style: TextStyle(
                    color: ForjaShellColors.textPrimary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _persist(
                  _config.copyWith(
                    leagues: List<String>.from(
                      LiveMatchesIptvSportsConfig.allLeagues,
                    ),
                  ),
                ),
                child: const Text('All'),
              ),
              TextButton(
                onPressed: () => _persist(_config.copyWith(leagues: const [])),
                child: const Text('None'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final league in LiveMatchesIptvSportsConfig.allLeagues)
                FilterChip(
                  label: Text(
                    LiveMatchesIptvSportsConfig.leagueLabels[league] ?? league,
                  ),
                  selected: _config.leagues.contains(league),
                  onSelected: (_) => _toggleLeague(league),
                  selectedColor:
                      ForjaShellColors.brandGreen.withValues(alpha: 0.25),
                  checkmarkColor: ForjaShellColors.brandGreen,
                  labelStyle: TextStyle(
                    color: _config.leagues.contains(league)
                        ? ForjaShellColors.textPrimary
                        : ForjaShellColors.textSecondary,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
                  ),
                  backgroundColor: Colors.transparent,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Text(
            'IPTV folders',
            style: TextStyle(
              color: ForjaShellColors.textPrimary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
          child: Text(
            'Optional. Leave as All live (default) — no need to tick folders. '
            'Open a sport only to narrow. Global is searched for every game.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        SettingsActionRow(
          title: LiveMatchesIptvSportsConfig.sportFamilyLabels['GLOBAL']!,
          subtitle: _categorySubtitle('GLOBAL'),
          onTap: () => _editCategories('GLOBAL'),
        ),
        for (final family in _config.activeSportFamilies)
          SettingsActionRow(
            title: LiveMatchesIptvSportsConfig.sportFamilyLabels[family] ??
                family,
            subtitle: _categorySubtitle(family),
            onTap: () => _editCategories(family),
          ),
      ],
    );
  }
}

class _CategoryMultiPickSheet extends StatefulWidget {
  const _CategoryMultiPickSheet({
    required this.title,
    required this.categories,
    required this.initiallySelected,
  });

  final String title;
  final List<IptvCategory> categories;
  final Set<String> initiallySelected;

  @override
  State<_CategoryMultiPickSheet> createState() =>
      _CategoryMultiPickSheetState();
}

class _CategoryMultiPickSheetState extends State<_CategoryMultiPickSheet> {
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Empty config = all live. Show every folder checked so users don't
    // think they must tick thousands by hand.
    if (widget.initiallySelected.isEmpty) {
      _selected = widget.categories.map((c) => c.id).toSet();
    } else {
      _selected = Set<String>.from(widget.initiallySelected);
    }
  }

  /// All checked (or none) → empty set → engine searches all live.
  Set<String> _resultForDone() {
    if (_selected.isEmpty ||
        _selected.length >= widget.categories.length) {
      return <String>{};
    }
    return Set<String>.from(_selected);
  }

  List<IptvCategory> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.categories;
    return widget.categories
        .where((c) => c.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.7;
    final filtered = _filtered;
    final allOn = widget.categories.isNotEmpty &&
        _selected.length >= widget.categories.length;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _resultForDone()),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              allOn || _selected.isEmpty
                  ? 'All live channels selected — Done saves that (no per-folder list).'
                  : '${_selected.length} of ${widget.categories.length} folders — uncheck to exclude.',
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selected = widget.categories.map((c) => c.id).toSet();
                    });
                  },
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selected.clear());
                  },
                  child: const Text('None'),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} shown',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter folders…',
                hintStyle: TextStyle(
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.6),
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(color: ForjaShellColors.textPrimary),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                final on = _selected.contains(c.id);
                return CheckboxListTile(
                  value: on,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(c.id);
                      } else {
                        _selected.remove(c.id);
                      }
                    });
                  },
                  title: Text(
                    c.name,
                    style: const TextStyle(color: ForjaShellColors.textPrimary),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: ForjaShellColors.brandGreen,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
