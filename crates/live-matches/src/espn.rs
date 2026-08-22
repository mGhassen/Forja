//! ESPN public scoreboard → today's games (Sportio-compatible shape).

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};

use crate::fetch::{http_get_json, ok_items};

/// ESPN scoreboard blocks common browser UAs from many IPs; plain client strings work.
const UA: &str = "curl/8.7.1";

fn espn_headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), UA.into()),
        ("Accept".into(), "application/json".into()),
    ])
}

const ESPN_ENDPOINTS: &[(&str, &str)] = &[
    (
        "NBA",
        "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard",
    ),
    (
        "NFL",
        "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard",
    ),
    (
        "MLB",
        "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard",
    ),
    (
        "NHL",
        "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard",
    ),
    (
        "WNBA",
        "https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard",
    ),
    (
        "NCAAMB",
        "https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard",
    ),
    (
        "NCAAWB",
        "https://site.api.espn.com/apis/site/v2/sports/basketball/womens-college-basketball/scoreboard",
    ),
    (
        "NCAAFB",
        "https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard",
    ),
    (
        "EPL",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard",
    ),
    (
        "MLS",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/scoreboard",
    ),
    (
        "LALIGA",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard",
    ),
    (
        "SERIEA",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/ita.1/scoreboard",
    ),
    (
        "BUNDESLIGA",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/ger.1/scoreboard",
    ),
    (
        "LIGUE1",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1/scoreboard",
    ),
    (
        "UCL",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.champions/scoreboard",
    ),
    (
        "EUROPA",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.europa/scoreboard",
    ),
    (
        "EREDIVISIE",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/ned.1/scoreboard",
    ),
    (
        "LIGAPORTUGAL",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/por.1/scoreboard",
    ),
    (
        "LIGAMX",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/mex.1/scoreboard",
    ),
    (
        "WORLDCUP",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard",
    ),
    (
        "UFC",
        "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard",
    ),
];

const ESPN_LEAGUES: &[(&str, &str)] = &[
    ("NBA", "nba"),
    ("NFL", "nfl"),
    ("MLB", "mlb"),
    ("NHL", "nhl"),
    ("WNBA", "wnba"),
    ("NCAAMB", "mens-college-basketball"),
    ("NCAAWB", "womens-college-basketball"),
    ("NCAAFB", "college-football"),
    ("EPL", "eng.1"),
    ("MLS", "usa.1"),
    ("LALIGA", "esp.1"),
    ("SERIEA", "ita.1"),
    ("BUNDESLIGA", "ger.1"),
    ("LIGUE1", "fra.1"),
    ("UCL", "uefa.champions"),
    ("EUROPA", "uefa.europa"),
    ("EREDIVISIE", "ned.1"),
    ("LIGAPORTUGAL", "por.1"),
    ("LIGAMX", "mex.1"),
    ("WORLDCUP", "fifa.world"),
    ("UFC", "ufc"),
];

const NCAA_SPORTS: &[&str] = &["NCAAMB", "NCAAWB", "NCAAFB"];

/// Sport family path segment for the ESPN teams API.
fn sport_family(sport: &str) -> Option<&'static str> {
    let endpoint = ESPN_ENDPOINTS
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case(sport))?
        .1;
    // .../sports/{family}/{league}/scoreboard
    let rest = endpoint.split("/sports/").nth(1)?;
    Some(rest.split('/').next()?)
}

fn league_slug(sport: &str) -> Option<&'static str> {
    ESPN_LEAGUES
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case(sport))
        .map(|(_, v)| *v)
}

fn endpoint_for(sport: &str) -> Option<&'static str> {
    ESPN_ENDPOINTS
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case(sport))
        .map(|(_, v)| *v)
}

/// Sport family for IPTV folder mapping (Settings → Forja Sports).
pub fn category_for_league(sport: &str) -> &'static str {
    match sport.to_uppercase().as_str() {
        "NBA" | "WNBA" | "NCAAMB" | "NCAAWB" => "basketball",
        "NFL" | "NCAAFB" => "football",
        "MLB" => "baseball",
        "NHL" => "hockey",
        "EPL" | "MLS" | "LALIGA" | "SERIEA" | "BUNDESLIGA" | "LIGUE1" | "UCL"
        | "EUROPA" | "EREDIVISIE" | "LIGAPORTUGAL" | "LIGAMX" | "WORLDCUP" => "soccer",
        "UFC" => "mma",
        _ => "other",
    }
}

/// Live Matches sport chip label — one chip per league, not a single "Soccer" bucket.
pub fn league_chip_label(sport: &str) -> &'static str {
    match sport.to_uppercase().as_str() {
        "NBA" => "NBA",
        "NFL" => "NFL",
        "MLB" => "MLB",
        "NHL" => "NHL",
        "WNBA" => "WNBA",
        "NCAAMB" => "NCAA Men's Basketball",
        "NCAAWB" => "NCAA Women's Basketball",
        "NCAAFB" => "NCAA Football",
        "EPL" => "Premier League",
        "MLS" => "MLS",
        "LALIGA" => "La Liga",
        "SERIEA" => "Serie A",
        "BUNDESLIGA" => "Bundesliga",
        "LIGUE1" => "Ligue 1",
        "UCL" => "Champions League",
        "EUROPA" => "Europa League",
        "EREDIVISIE" => "Eredivisie",
        "LIGAPORTUGAL" => "Primeira Liga",
        "LIGAMX" => "Liga MX",
        "WORLDCUP" => "FIFA World Cup",
        "UFC" => "UFC",
        _ => category_for_league(sport),
    }
}

/// UTC YYYYMMDD for "today" when Dart does not pass a local date.
pub fn utc_date_yyyymmdd() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    // Crude civil date from unix days (UTC only).
    let days = (secs / 86400) as i64;
    let (y, m, d) = civil_from_days(days);
    format!("{y:04}{m:02}{d:02}")
}

/// Algorithm from Howard Hinnant (civil_from_days).
fn civil_from_days(z: i64) -> (i32, u32, u32) {
    let z = z + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = (z - era * 146097) as u32;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = (yoe as i64) + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    (y as i32, m, d)
}

/// Parse ISO-8601 / RFC3339-ish kickoff to epoch ms. Returns 0 on failure.
pub fn parse_iso_ms(raw: &str) -> i64 {
    let s = raw.trim();
    if s.is_empty() {
        return 0;
    }
    // 2026-08-20T19:30:00Z / 2026-08-20T19:30:00.000Z / with offset
    let (date_part, rest) = match s.split_once('T') {
        Some(p) => p,
        None => return 0,
    };
    let date_bits: Vec<_> = date_part.split('-').collect();
    if date_bits.len() != 3 {
        return 0;
    }
    let y: i32 = date_bits[0].parse().unwrap_or(0);
    let mo: u32 = date_bits[1].parse().unwrap_or(0);
    let d: u32 = date_bits[2].parse().unwrap_or(0);
    if y == 0 || mo == 0 || d == 0 {
        return 0;
    }

    let time_part = rest.trim_end_matches('Z');
    let time_part = time_part
        .split(['+', '-'])
        .next()
        .unwrap_or(time_part);
    let time_part = time_part.split('.').next().unwrap_or(time_part);
    let tb: Vec<_> = time_part.split(':').collect();
    if tb.len() < 2 {
        return 0;
    }
    let h: u32 = tb[0].parse().unwrap_or(0);
    let mi: u32 = tb[1].parse().unwrap_or(0);
    let se: u32 = if tb.len() > 2 {
        tb[2].parse().unwrap_or(0)
    } else {
        0
    };

    // Offset: trailing Z = 0; otherwise look for +HH:MM / -HH:MM at end of rest
    let mut offset_secs: i64 = 0;
    if !rest.ends_with('Z') && !rest.ends_with('z') {
        if let Some(idx) = rest.rfind(['+', '-']) {
            if idx > 0 {
                let sign = if rest.as_bytes()[idx] == b'+' { 1i64 } else { -1 };
                let off = &rest[idx + 1..];
                let parts: Vec<_> = off.split(':').collect();
                if parts.len() >= 2 {
                    let oh: i64 = parts[0].parse().unwrap_or(0);
                    let om: i64 = parts[1].parse().unwrap_or(0);
                    offset_secs = sign * (oh * 3600 + om * 60);
                }
            }
        }
    }

    let days = days_from_civil(y, mo, d);
    let secs = days * 86400 + (h as i64) * 3600 + (mi as i64) * 60 + (se as i64) - offset_secs;
    secs * 1000
}

fn days_from_civil(y: i32, m: u32, d: u32) -> i64 {
    let mut y = y as i64;
    let m = m as i64;
    let d = d as i64;
    if m <= 2 {
        y -= 1;
    }
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

fn team_field(team: &Value, keys: &[&str]) -> String {
    for k in keys {
        if let Some(v) = team.get(k).and_then(|x| x.as_str()) {
            let t = v.trim();
            if !t.is_empty() {
                return t.to_string();
            }
        }
    }
    String::new()
}

fn map_game(sport: &str, event: &Value) -> Option<Value> {
    let competition = event
        .get("competitions")
        .and_then(|c| c.as_array())
        .and_then(|a| a.first())?;
    let competitors = competition
        .get("competitors")
        .and_then(|c| c.as_array())
        .cloned()
        .unwrap_or_default();
    let home = competitors
        .iter()
        .find(|c| c.get("homeAway").and_then(|v| v.as_str()) == Some("home"))
        .cloned()
        .unwrap_or_else(|| json!({}));
    let away = competitors
        .iter()
        .find(|c| c.get("homeAway").and_then(|v| v.as_str()) == Some("away"))
        .cloned()
        .unwrap_or_else(|| json!({}));

    let home_team = home.get("team").cloned().unwrap_or(json!({}));
    let away_team = away.get("team").cloned().unwrap_or(json!({}));

    let home_nick = {
        let n = team_field(&home_team, &["name", "shortDisplayName", "displayName"]);
        if n.is_empty() {
            "Home".into()
        } else {
            n
        }
    };
    let away_nick = {
        let n = team_field(&away_team, &["name", "shortDisplayName", "displayName"]);
        if n.is_empty() {
            "Away".into()
        } else {
            n
        }
    };
    let home_full = {
        let n = team_field(&home_team, &["displayName"]);
        if n.is_empty() {
            home_nick.clone()
        } else {
            n
        }
    };
    let away_full = {
        let n = team_field(&away_team, &["displayName"]);
        if n.is_empty() {
            away_nick.clone()
        } else {
            n
        }
    };
    let home_abbr = team_field(&home_team, &["abbreviation"]);
    let away_abbr = team_field(&away_team, &["abbreviation"]);
    let home_logo = team_field(&home_team, &["logo"]);
    let away_logo = team_field(&away_team, &["logo"]);

    let id = event
        .get("id")
        .map(|v| match v {
            Value::String(s) => s.clone(),
            Value::Number(n) => n.to_string(),
            _ => String::new(),
        })
        .filter(|s| !s.is_empty())?;

    let name = event
        .get("name")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .unwrap_or_else(|| format!("{away_full} vs {home_full}"));

    let date = event
        .get("date")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let date_ms = parse_iso_ms(&date);
    let status = event
        .pointer("/status/type/detail")
        .and_then(|v| v.as_str())
        .unwrap_or("Scheduled")
        .to_string();
    let status_state = event
        .pointer("/status/type/state")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let live = status_state.eq_ignore_ascii_case("in")
        || status.to_uppercase().contains("IN PROGRESS")
        || status.to_uppercase().contains("HALFTIME");

    let description = format!(
        "{} VS. {}\n{}",
        away_nick.to_uppercase(),
        home_nick.to_uppercase(),
        status
    );

    Some(json!({
        "id": id,
        "sport": sport.to_uppercase(),
        "category": league_chip_label(sport),
        "sportFamily": category_for_league(sport),
        "name": name,
        "title": name,
        "homeTeam": home_full,
        "awayTeam": away_full,
        "homeNick": home_nick,
        "awayNick": away_nick,
        "homeAbbr": home_abbr,
        "awayAbbr": away_abbr,
        "homeLogo": home_logo,
        "awayLogo": away_logo,
        "poster": if !home_logo.is_empty() { home_logo.clone() } else { away_logo.clone() },
        "description": description,
        "status": status,
        "date": date,
        "dateMs": date_ms,
        "live": live,
    }))
}

fn map_ufc_event(event: &Value) -> Option<Value> {
    let competition = event
        .get("competitions")
        .and_then(|c| c.as_array())
        .and_then(|a| a.first())?;
    let competitors = competition
        .get("competitors")
        .and_then(|c| c.as_array())
        .cloned()
        .unwrap_or_default();
    if competitors.len() < 2 {
        return None;
    }
    let a = &competitors[0];
    let b = &competitors[1];
    let name_a = a
        .pointer("/athlete/displayName")
        .and_then(|v| v.as_str())
        .unwrap_or("Fighter A")
        .to_string();
    let name_b = b
        .pointer("/athlete/displayName")
        .and_then(|v| v.as_str())
        .unwrap_or("Fighter B")
        .to_string();
    let id = event
        .get("id")
        .map(|v| match v {
            Value::String(s) => s.clone(),
            Value::Number(n) => n.to_string(),
            _ => String::new(),
        })
        .filter(|s| !s.is_empty())?;
    let event_name = event
        .get("name")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .unwrap_or_else(|| format!("{name_a} vs {name_b}"));
    let date = competition
        .get("date")
        .or_else(|| event.get("date"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let date_ms = parse_iso_ms(&date);
    let status = competition
        .pointer("/status/type/shortDetail")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let live = status.to_uppercase().contains("LIVE")
        || competition
            .pointer("/status/type/state")
            .and_then(|v| v.as_str())
            == Some("in");

    Some(json!({
        "id": id,
        "sport": "UFC",
        "category": "UFC",
        "sportFamily": "mma",
        "name": event_name,
        "title": event_name,
        "homeTeam": name_a,
        "awayTeam": name_b,
        "homeNick": name_a,
        "awayNick": name_b,
        "homeAbbr": "",
        "awayAbbr": "",
        "homeLogo": "",
        "awayLogo": "",
        "poster": "",
        "description": event_name,
        "status": status,
        "date": date,
        "dateMs": date_ms,
        "live": live,
    }))
}

fn fetch_scoreboard(sport: &str, date_yyyymmdd: &str) -> Vec<Value> {
    let endpoint = match endpoint_for(sport) {
        Some(u) => u,
        None => return vec![],
    };
    let ncaa = NCAA_SPORTS
        .iter()
        .any(|s| s.eq_ignore_ascii_case(sport));
    let ncaa_params = if ncaa {
        "&groups=50&limit=500"
    } else {
        ""
    };
    let url = format!("{endpoint}?dates={date_yyyymmdd}{ncaa_params}");
    let body = match crate::fetch::http_get_catalog(&url, &espn_headers(), 12) {
        Some(b) => b,
        None => return vec![],
    };
    let root: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return vec![],
    };
    let events = root
        .get("events")
        .and_then(|e| e.as_array())
        .cloned()
        .unwrap_or_default();

    if sport.eq_ignore_ascii_case("UFC") {
        return events.iter().filter_map(map_ufc_event).collect();
    }
    events
        .iter()
        .filter_map(|e| map_game(sport, e))
        .collect()
}

/// Fetch today's games for the given league keys.
pub fn sport_match_games(leagues: &[String], date_yyyymmdd: Option<&str>) -> String {
    let date = date_yyyymmdd
        .map(|s| s.trim().to_string())
        .filter(|s| s.len() == 8 && s.chars().all(|c| c.is_ascii_digit()))
        .unwrap_or_else(utc_date_yyyymmdd);

    let mut items = Vec::new();
    let leagues: Vec<String> = if leagues.is_empty() {
        ESPN_ENDPOINTS
            .iter()
            .map(|(k, _)| (*k).to_string())
            .collect()
    } else {
        leagues.to_vec()
    };

    for league in leagues {
        let sport = league.trim().to_uppercase();
        if sport.is_empty() {
            continue;
        }
        items.extend(fetch_scoreboard(&sport, &date));
    }

    items.sort_by(|a, b| {
        let da = a.get("dateMs").and_then(|v| v.as_i64()).unwrap_or(0);
        let db = b.get("dateMs").and_then(|v| v.as_i64()).unwrap_or(0);
        da.cmp(&db)
    });
    ok_items(items)
}

fn game_to_catalog_row(game: &Value, plugin_id: &str) -> Option<Value> {
    let id = game.get("id").and_then(|v| v.as_str())?.trim();
    if id.is_empty() {
        return None;
    }
    let title = game
        .get("title")
        .or_else(|| game.get("name"))
        .and_then(|v| v.as_str())
        .unwrap_or("ESPN");
    let category = game
        .get("category")
        .and_then(|v| v.as_str())
        .unwrap_or("other");
    let date_ms = game.get("dateMs").and_then(|v| v.as_i64()).unwrap_or(0);
    let live = game.get("live").and_then(|v| v.as_bool()).unwrap_or(false);
    let home_logo = game
        .get("homeLogo")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let away_logo = game
        .get("awayLogo")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let poster = if !home_logo.is_empty() {
        home_logo
    } else {
        away_logo
    };
    let sport_match_game = json!({
        "id": id,
        "title": title,
        "sport": game.get("sport").and_then(|v| v.as_str()).unwrap_or(""),
        "category": category,
        "sportFamily": game.get("sportFamily").and_then(|v| v.as_str()).unwrap_or(""),
        "homeTeam": game.get("homeTeam").and_then(|v| v.as_str()).unwrap_or(""),
        "awayTeam": game.get("awayTeam").and_then(|v| v.as_str()).unwrap_or(""),
        "homeNick": game.get("homeNick").and_then(|v| v.as_str()).unwrap_or(""),
        "awayNick": game.get("awayNick").and_then(|v| v.as_str()).unwrap_or(""),
        "homeAbbr": game.get("homeAbbr").and_then(|v| v.as_str()).unwrap_or(""),
        "awayAbbr": game.get("awayAbbr").and_then(|v| v.as_str()).unwrap_or(""),
        "dateMs": date_ms,
        "date": game.get("date").and_then(|v| v.as_str()).unwrap_or(""),
    });
    Some(json!({
        "id": format!("espn:{id}"),
        "title": title,
        "category": category,
        "date": date_ms,
        "poster": poster,
        "popular": false,
        "airing": live,
        "homeTeam": game.get("homeTeam").and_then(|v| v.as_str()).unwrap_or(""),
        "awayTeam": game.get("awayTeam").and_then(|v| v.as_str()).unwrap_or(""),
        "homeBadge": home_logo,
        "awayBadge": away_logo,
        "sources": [],
        "catalog": "forja_live",
        "pluginId": plugin_id,
        "sportMatchGame": sport_match_game,
    }))
}

/// Forja Live `catalog-espn` rows — mirrors `assets/plugins/catalog/espn.js`.
pub fn forja_live_catalog_rows(
    leagues: &[String],
    date_yyyymmdd: Option<&str>,
    plugin_id: &str,
) -> Vec<Value> {
    let date = date_yyyymmdd
        .map(|s| s.trim().to_string())
        .filter(|s| s.len() == 8 && s.chars().all(|c| c.is_ascii_digit()))
        .unwrap_or_else(utc_date_yyyymmdd);

    let leagues: Vec<String> = if leagues.is_empty() {
        ESPN_ENDPOINTS
            .iter()
            .map(|(k, _)| (*k).to_string())
            .collect()
    } else {
        leagues.to_vec()
    };

    let mut rows = Vec::new();
    for league in leagues {
        let sport = league.trim().to_uppercase();
        if sport.is_empty() {
            continue;
        }
        for game in fetch_scoreboard(&sport, &date) {
            if let Some(row) = game_to_catalog_row(&game, plugin_id) {
                rows.push(row);
            }
        }
    }
    rows.sort_by(|a, b| {
        let da = a.get("date").and_then(|v| v.as_i64()).unwrap_or(0);
        let db = b.get("date").and_then(|v| v.as_i64()).unwrap_or(0);
        da.cmp(&db)
    });
    rows
}

struct TeamCacheEntry {
    fetched_at: Instant,
    names: Vec<String>,
}

fn team_cache() -> &'static Mutex<HashMap<String, TeamCacheEntry>> {
    static CACHE: OnceLock<Mutex<HashMap<String, TeamCacheEntry>>> = OnceLock::new();
    CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

const TEAM_CACHE_TTL: Duration = Duration::from_secs(24 * 60 * 60);

/// League roster display names for foreign-team exclusion.
pub fn fetch_all_team_names(sport: &str) -> Vec<String> {
    let key = sport.to_uppercase();
    if key == "UFC" {
        return vec![];
    }

    if let Ok(cache) = team_cache().lock() {
        if let Some(entry) = cache.get(&key) {
            if entry.fetched_at.elapsed() < TEAM_CACHE_TTL {
                return entry.names.clone();
            }
        }
    }

    let family = match sport_family(&key) {
        Some(f) => f,
        None => return vec![],
    };
    let league = match league_slug(&key) {
        Some(l) => l,
        None => return vec![],
    };
    let url = format!("https://site.api.espn.com/apis/site/v2/sports/{family}/{league}/teams");
    let body = match http_get_json(&url, &espn_headers(), 10) {
        Some(b) => b,
        None => {
            if let Ok(cache) = team_cache().lock() {
                if let Some(entry) = cache.get(&key) {
                    return entry.names.clone();
                }
            }
            return vec![];
        }
    };
    let root: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return vec![],
    };
    let teams = root
        .pointer("/sports/0/leagues/0/teams")
        .and_then(|t| t.as_array())
        .cloned()
        .unwrap_or_default();
    let names: Vec<String> = teams
        .iter()
        .filter_map(|t| {
            t.pointer("/team/displayName")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string())
        })
        .filter(|s| !s.is_empty())
        .collect();

    if let Ok(mut cache) = team_cache().lock() {
        cache.insert(
            key,
            TeamCacheEntry {
                fetched_at: Instant::now(),
                names: names.clone(),
            },
        );
    }
    names
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_iso_z() {
        let ms = parse_iso_ms("2026-08-20T19:30:00Z");
        assert!(ms > 0);
    }

    #[test]
    fn category_nba() {
        assert_eq!(category_for_league("NBA"), "basketball");
        assert_eq!(category_for_league("EPL"), "soccer");
    }

    #[test]
    fn utc_date_len() {
        assert_eq!(utc_date_yyyymmdd().len(), 8);
    }
}
