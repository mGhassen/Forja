import 'package:forja/shared/engine/live/match_event.dart';
import 'package:forja/shared/engine/live/match_team_parse.dart';

/// Soft same-fixture check for schedule merge + Providers sibling resolve.
///
/// Exact pair keys miss `Feyenoord` ↔ `Feyenoord Rotterdam` and
/// `Away at Home` ↔ `Home vs Away`. Soft team equality + kickoff window
/// (and session / title fallbacks) cover those.
bool liveCatalogEventsSoftMatch({
  required String idA,
  required String titleA,
  required String? homeTeamA,
  required String? awayTeamA,
  required int dateMsA,
  required String idB,
  required String titleB,
  required String? homeTeamB,
  required String? awayTeamB,
  required int dateMsB,
  bool alwaysOnA = false,
  bool alwaysOnB = false,
}) {
  if (idA.isNotEmpty && idB.isNotEmpty && idA == idB) return true;

  // Prefer soft team equality. Do not use matchTextKey pair keys — those
  // strip City/United and falsely equate Manchester City with Manchester United.
  final (homeA, awayA) = resolveLiveMatchTeams(
    homeTeam: homeTeamA,
    awayTeam: awayTeamA,
    title: titleA,
  );
  final (homeB, awayB) = resolveLiveMatchTeams(
    homeTeam: homeTeamB,
    awayTeam: awayTeamB,
    title: titleB,
  );
  final haveTeams = homeA.isNotEmpty &&
      awayA.isNotEmpty &&
      homeB.isNotEmpty &&
      awayB.isNotEmpty;
  if (haveTeams) {
    // Dateless schedule rows with sources[] are isAlwaysOn — still merge when
    // both sides parse as the same fixture pair (kickoff missing ≠ 24/7).
    return liveTeamPairSoftEqual(homeA, awayA, homeB, awayB) &&
        liveEventDatesCloseEnough(dateMsA, dateMsB);
  }

  // True 24/7 / always-on without a team pair must not collapse via title keys.
  if (alwaysOnA || alwaysOnB) return false;

  if (liveEventSessionSoftEqual(titleA, titleB) &&
      liveEventDatesCloseEnough(dateMsA, dateMsB)) {
    return true;
  }

  final titleKeyA = matchTextKey(titleA);
  final titleKeyB = matchTextKey(titleB);
  if (titleKeyA.isEmpty || titleKeyB.isEmpty || titleKeyA != titleKeyB) {
    return false;
  }
  return liveEventDatesCloseEnough(dateMsA, dateMsB);
}

bool liveEventDatesCloseEnough(int dateMsA, int dateMsB) {
  if (dateMsA <= 0 || dateMsB <= 0) return true;
  return (dateMsA - dateMsB).abs() <=
      const Duration(hours: 6).inMilliseconds;
}

/// Coarse bucket so soft name variants still land in the same candidate set.
///
/// Exact `matchTeamPairKey` splits `Feyenoord` vs `Feyenoord Rotterdam` into
/// different buckets — soft equality never runs. First token per side keeps
/// them together; `_same` still rejects City vs United etc.
String? liveEventMergeBucketKey({
  required String? homeTeam,
  required String? awayTeam,
  required String title,
  bool alwaysOn = false,
}) {
  final (home, away) = resolveLiveMatchTeams(
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    title: title,
  );
  final homeTok = liveTeamMatchTokens(home);
  final awayTok = liveTeamMatchTokens(away);
  if (homeTok.isNotEmpty && awayTok.isNotEmpty) {
    // Team pair even when isAlwaysOn (dateless + sources) so soft-match runs.
    final pair = [homeTok.first, awayTok.first]..sort();
    return 'c:${pair.join('|')}';
  }
  // Real 24/7 without teams — keep out of coarse title buckets.
  if (alwaysOn) return null;
  final titleKey = matchTextKey(title);
  if (titleKey.isEmpty) return null;
  return 'n:$titleKey';
}

bool liveCatalogEventsSoftMatchMaps(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final ma = MatchEvent.fromLegacyRow(a);
  final mb = MatchEvent.fromLegacyRow(b);
  return liveCatalogEventsSoftMatch(
    idA: ma.id,
    titleA: ma.title,
    homeTeamA: ma.homeTeam,
    awayTeamA: ma.awayTeam,
    dateMsA: ma.dateMs,
    idB: mb.id,
    titleB: mb.title,
    homeTeamB: mb.homeTeam,
    awayTeamB: mb.awayTeam,
    dateMsB: mb.dateMs,
    alwaysOnA: ma.isAlwaysOn,
    alwaysOnB: mb.isAlwaysOn,
  );
}
