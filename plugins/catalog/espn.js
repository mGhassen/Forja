var SPECS = {
  "leagues": [
    "NBA",
    "NFL",
    "MLB",
    "NHL",
    "WNBA",
    "NCAAMB",
    "NCAAWB",
    "NCAAFB",
    "EPL",
    "MLS",
    "LALIGA",
    "SERIEA",
    "BUNDESLIGA",
    "LIGUE1",
    "UCL",
    "EUROPA",
    "EREDIVISIE",
    "LIGAPORTUGAL",
    "LIGAMX",
    "WORLDCUP",
    "UFC"
  ]
};

function ua() {
  return 'curl/8.7.1';
}

var LEAGUE_ENDPOINTS = {
  NBA: 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard',
  NFL: 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard',
  MLB: 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard',
  NHL: 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard',
  WNBA: 'https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard',
  NCAAMB: 'https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard',
  NCAAWB: 'https://site.api.espn.com/apis/site/v2/sports/basketball/womens-college-basketball/scoreboard',
  NCAAFB: 'https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard',
  EPL: 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard',
  MLS: 'https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/scoreboard',
  LALIGA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard',
  SERIEA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/ita.1/scoreboard',
  BUNDESLIGA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/ger.1/scoreboard',
  LIGUE1: 'https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1/scoreboard',
  UCL: 'https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.champions/scoreboard',
  EUROPA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.europa/scoreboard',
  EREDIVISIE: 'https://site.api.espn.com/apis/site/v2/sports/soccer/ned.1/scoreboard',
  LIGAPORTUGAL: 'https://site.api.espn.com/apis/site/v2/sports/soccer/por.1/scoreboard',
  LIGAMX: 'https://site.api.espn.com/apis/site/v2/sports/soccer/mex.1/scoreboard',
  WORLDCUP: 'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard',
  UFC: 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard',
};

var LEAGUE_LABELS = {
  NBA: 'NBA',
  NFL: 'NFL',
  MLB: 'MLB',
  NHL: 'NHL',
  WNBA: 'WNBA',
  NCAAMB: "NCAA Men's Basketball",
  NCAAWB: "NCAA Women's Basketball",
  NCAAFB: 'NCAA Football',
  EPL: 'Premier League',
  MLS: 'MLS',
  LALIGA: 'La Liga',
  SERIEA: 'Serie A',
  BUNDESLIGA: 'Bundesliga',
  LIGUE1: 'Ligue 1',
  UCL: 'Champions League',
  EUROPA: 'Europa League',
  EREDIVISIE: 'Eredivisie',
  LIGAPORTUGAL: 'Primeira Liga',
  LIGAMX: 'Liga MX',
  WORLDCUP: 'FIFA World Cup',
  UFC: 'UFC',
};

var NCAA_LEAGUES = { NCAAMB: true, NCAAWB: true, NCAAFB: true };

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'espn');
}

function leagueFamily(league) {
  switch (String(league || '').toUpperCase()) {
    case 'NBA':
    case 'WNBA':
    case 'NCAAMB':
    case 'NCAAWB':
      return 'basketball';
    case 'NFL':
    case 'NCAAFB':
      return 'football';
    case 'MLB':
      return 'baseball';
    case 'NHL':
      return 'hockey';
    case 'EPL':
    case 'MLS':
    case 'LALIGA':
    case 'SERIEA':
    case 'BUNDESLIGA':
    case 'LIGUE1':
    case 'UCL':
    case 'EUROPA':
    case 'EREDIVISIE':
    case 'LIGAPORTUGAL':
    case 'LIGAMX':
    case 'WORLDCUP':
      return 'soccer';
    case 'UFC':
      return 'mma';
    default:
      return 'other';
  }
}

function leagueChipLabel(league) {
  var key = String(league || '').toUpperCase();
  return LEAGUE_LABELS[key] || leagueFamily(league);
}

function parseIsoMs(raw) {
  var s = String(raw || '').trim();
  if (!s) return 0;
  var t = Date.parse(s);
  return isNaN(t) ? 0 : t;
}

function teamField(team, keys) {
  if (!team) return '';
  for (var i = 0; i < keys.length; i++) {
    var v = team[keys[i]];
    if (v != null && String(v).trim()) return String(v).trim();
  }
  return '';
}

function mapGame(league, event, pluginId) {
  var comps = event.competitions || [];
  var competition = comps[0];
  if (!competition) return null;
  var competitors = competition.competitors || [];
  var home = null;
  var away = null;
  competitors.forEach(function (c) {
    if (c.homeAway === 'home') home = c;
    if (c.homeAway === 'away') away = c;
  });
  home = home || { team: {} };
  away = away || { team: {} };
  var homeTeam = home.team || {};
  var awayTeam = away.team || {};
  var homeNick = teamField(homeTeam, ['name', 'shortDisplayName', 'displayName']) || 'Home';
  var awayNick = teamField(awayTeam, ['name', 'shortDisplayName', 'displayName']) || 'Away';
  var homeFull = teamField(homeTeam, ['displayName']) || homeNick;
  var awayFull = teamField(awayTeam, ['displayName']) || awayNick;
  var id = event.id != null ? String(event.id) : '';
  if (!id) return null;
  var name = event.name || (awayFull + ' vs ' + homeFull);
  var date = event.date || '';
  var status = (event.status && event.status.type && event.status.type.detail) || 'Scheduled';
  var state = (event.status && event.status.type && event.status.type.state) || '';
  var live = state.toLowerCase() === 'in' ||
    String(status).toUpperCase().indexOf('IN PROGRESS') >= 0 ||
    String(status).toUpperCase().indexOf('HALFTIME') >= 0;
  var homeLogo = teamField(homeTeam, ['logo']);
  var awayLogo = teamField(awayTeam, ['logo']);
  var leagueKey = String(league).toUpperCase();
  var sportMatchGame = {
    id: id,
    title: name,
    sport: leagueKey,
    category: leagueChipLabel(league),
    sportFamily: leagueFamily(league),
    homeTeam: homeFull,
    awayTeam: awayFull,
    homeNick: homeNick,
    awayNick: awayNick,
    homeAbbr: teamField(homeTeam, ['abbreviation']),
    awayAbbr: teamField(awayTeam, ['abbreviation']),
    dateMs: parseIsoMs(date),
    date: date,
  };
  return {
    id: 'espn:' + id,
    title: name,
    category: leagueChipLabel(league),
    date: parseIsoMs(date),
    poster: homeLogo || awayLogo || '',
    popular: false,
    airing: live,
    homeTeam: homeFull,
    awayTeam: awayFull,
    homeBadge: homeLogo,
    awayBadge: awayLogo,
    sources: [],
    catalog: 'forja_live',
    pluginId: String(pluginId || 'espn'),
    sportMatchGame: sportMatchGame,
  };
}

async function fetchLeague(ctx, league, date, pluginId) {
  var url = LEAGUE_ENDPOINTS[String(league || '').toUpperCase()];
  if (!url) return [];
  var fetchUrl = url;
  if (date) fetchUrl += (url.indexOf('?') >= 0 ? '&' : '?') + 'dates=' + date;
  if (NCAA_LEAGUES[String(league || '').toUpperCase()]) {
    fetchUrl += '&groups=50&limit=500';
  }
  var res = await ctx.fetch(fetchUrl, {
    headers: { 'User-Agent': ua(), Accept: 'application/json' },
  });
  if (!res.ok) return [];
  var data = await res.json();
  var events = data.events || [];
  var out = [];
  events.forEach(function (ev) {
    var row = mapGame(league, ev, pluginId);
    if (row) out.push(row);
  });
  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var pluginId = pluginIdFromCtx(ctx, cfg);
  var leaguesRaw = cfg.leagues;
  var leagues = leaguesRaw && leaguesRaw.length
    ? leaguesRaw
    : Object.keys(LEAGUE_ENDPOINTS);
  var date = String(cfg.date || '').trim();
  if (!date) {
    var now = new Date();
    var m = now.getMonth() + 1;
    var d = now.getDate();
    date = String(now.getFullYear()) +
      (m < 10 ? '0' : '') + m +
      (d < 10 ? '0' : '') + d;
  }
  var chunks = await Promise.all(leagues.map(function (lg) {
    return fetchLeague(ctx, lg, date, pluginId);
  }));
  return chunks.reduce(function (a, b) { return a.concat(b); }, []);
}
