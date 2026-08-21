import 'package:flutter/material.dart';
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
  bool _loading = true;
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
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
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

  Future<void> _toggleLeague(String league) async {
    final next = List<String>.from(_config.leagues);
    if (next.contains(league)) {
      next.remove(league);
    } else {
      next.add(league);
    }
    await _persist(_config.copyWith(leagues: next));
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
            'Here: enable and which leagues to match.',
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
          },
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
      ],
    );
  }
}
