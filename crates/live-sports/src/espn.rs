//! ESPN team-name roster for Live TV portal matching.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use serde_json::Value;

use crate::fetch::http_get_json;

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
}
