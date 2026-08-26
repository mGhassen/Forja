//! IPTV channel ↔ Live Matches event matcher.
//!
//! Pipeline: tokenize event (title, teams, sport chip) → score channel name +
//! Xtream category folder → fetch short EPG on top candidates → re-score with EPG.

use serde_json::{json, Value};

/// Normalized IPTV candidate (Xtream / Stalker / M3U).
#[derive(Debug, Clone)]
pub struct Candidate {
    pub name: String,
    pub description: String,
    pub start_timestamp: Option<f64>,
    /// Empty for Stalker (create_link deferred to play).
    pub stream_url: String,
    pub category_label: String,
    pub logo: String,
    /// Xtream stream_id or Stalker create_link `cmd`.
    pub stream_id: String,
    /// MAG `ch_id` for short EPG (Stalker); often empty on Xtream.
    pub epg_channel_id: String,
}

/// Game fields used for matching.
#[derive(Debug, Clone)]
pub struct MatchGame {
    pub home_team: String,
    pub away_team: String,
    pub home_nick: String,
    pub away_nick: String,
    pub home_abbr: String,
    pub away_abbr: String,
    #[allow(dead_code)]
    pub title: String,
    /// Event-specific tokens (title + parsed teams).
    pub specific_tokens: Vec<String>,
    /// Sport-chip tokens (e.g. motor-sports → motor, sports).
    pub sport_tokens: Vec<String>,
    /// Normalized title phrases for PPV-style channel names.
    pub title_phrases: Vec<String>,
    pub date_ms: i64,
}

impl MatchGame {
    pub fn from_json(v: &Value) -> Self {
        fn s(v: &Value, k: &str) -> String {
            v.get(k)
                .and_then(|x| x.as_str())
                .unwrap_or("")
                .to_string()
        }
        let date_ms = v
            .get("dateMs")
            .and_then(|x| x.as_i64())
            .or_else(|| {
                v.get("date")
                    .and_then(|x| x.as_str())
                    .map(crate::espn::parse_iso_ms)
            })
            .unwrap_or(0);
        let title = s(v, "title");
        let sport = s(v, "sport");
        let mut home_team = s(v, "homeTeam");
        let mut away_team = s(v, "awayTeam");
        if home_team.is_empty() || away_team.is_empty() {
            if let Some((h, a)) = parse_teams_from_title(&title) {
                if home_team.is_empty() {
                    home_team = h;
                }
                if away_team.is_empty() {
                    away_team = a;
                }
            }
        }
        let (specific_tokens, sport_tokens) = build_event_tokens(&title, &sport, &home_team, &away_team);
        let title_phrases = build_title_phrases(&title, &home_team, &away_team);
        Self {
            home_team,
            away_team,
            home_nick: s(v, "homeNick"),
            away_nick: s(v, "awayNick"),
            home_abbr: s(v, "homeAbbr"),
            away_abbr: s(v, "awayAbbr"),
            title,
            specific_tokens,
            sport_tokens,
            title_phrases,
            date_ms,
        }
    }

    pub fn is_team_game(&self) -> bool {
        let h = self.home_team.trim().to_lowercase();
        let a = self.away_team.trim().to_lowercase();
        !h.is_empty()
            && !a.is_empty()
            && h != "home"
            && a != "away"
            && h != "away"
            && a != "home"
    }
}

const TITLE_STOPWORDS: &[&str] = &[
    "the", "and", "for", "with", "live", "now", "cup", "final", "game", "match",
    "round", "day", "night", "week", "season", "series", "championship", "open",
    "event", "versus", "vs", "at",
];

/// Shared suffixes — matching these alone causes cross-fixture false positives.
const GENERIC_TEAM_TOKENS: &[&str] = &[
    "city", "united", "town", "rovers", "county", "athletic", "wanderers", "albion",
    "villa", "forest", "palace", "north", "south", "west", "east", "sport", "sports",
    "fc", "sc", "afc", "cf", "cd", "real", "inter", "sporting",
];

fn is_generic_team_token(w: &str) -> bool {
    GENERIC_TEAM_TOKENS.contains(&w)
}

/// Years and bare numbers match almost every sports EPG — never use alone.
fn is_weak_event_token(w: &str) -> bool {
    w.chars().all(|c| c.is_ascii_digit())
}

fn is_token(w: &str) -> bool {
    let w = w.trim();
    if w.is_empty() {
        return false;
    }
    if w.len() == 2 {
        return w.chars().any(|c| c.is_ascii_digit());
    }
    w.len() >= 3 && !TITLE_STOPWORDS.contains(&w)
}

fn tokenize_text(text: &str) -> Vec<String> {
    let lower = text.to_lowercase();
    let mut out = Vec::new();
    for token in lower.split(|c: char| !c.is_ascii_alphanumeric()) {
        if is_token(token) {
            out.push(token.to_string());
        }
    }
    out.sort();
    out.dedup();
    out
}

fn build_event_tokens(
    title: &str,
    sport: &str,
    home: &str,
    away: &str,
) -> (Vec<String>, Vec<String>) {
    let mut specific = tokenize_text(title);
    for team in [home, away] {
        for t in team_match_tokens(team) {
            if !specific.contains(&t) {
                specific.push(t);
            }
        }
    }
    specific.retain(|t| !is_generic_team_token(t) && !is_weak_event_token(t));
    specific.sort();
    specific.dedup();

    let sport_tokens = tokenize_text(sport);
    (specific, sport_tokens)
}

/// Collapse punctuation so `"PPV: Dutch Grand Prix HD"` matches event title.
fn normalize_phrase(text: &str) -> String {
    text.to_lowercase()
        .split(|c: char| !c.is_ascii_alphanumeric())
        .filter(|w| !w.is_empty() && !TITLE_STOPWORDS.contains(w))
        .collect::<Vec<_>>()
        .join(" ")
}

fn build_title_phrases(title: &str, home: &str, away: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut push = |phrase: String| {
        if phrase.len() >= 8 && !out.contains(&phrase) {
            out.push(phrase);
        }
    };
    push(normalize_phrase(title));
    if let Some(stem) = title.split(" - ").next() {
        push(normalize_phrase(stem));
    }
    if !home.trim().is_empty() && !away.trim().is_empty() {
        push(normalize_phrase(&format!("{} vs {}", home.trim(), away.trim())));
        push(normalize_phrase(&format!("{} v {}", home.trim(), away.trim())));
    }
    out
}

fn text_has_title_phrase(text: &str, phrases: &[String]) -> bool {
    if phrases.is_empty() {
        return false;
    }
    let norm = normalize_phrase(text);
    if norm.len() < 8 {
        return false;
    }
    phrases.iter().any(|p| norm.contains(p.as_str()))
}

fn parse_teams_from_title(title: &str) -> Option<(String, String)> {
    let title = title.trim();
    if title.is_empty() {
        return None;
    }
    if let Some((start, end)) = regex_lite_find(title, "vs") {
        let left = title[..start].trim();
        let right = title[end..].split(" - ").next().unwrap_or("").trim();
        if !left.is_empty() && !right.is_empty() {
            return Some((left.to_string(), right.to_string()));
        }
    }
    if let Some((start, end)) = regex_lite_find(title, "at|@") {
        let away = title[..start].trim();
        let home = title[end..].split(" - ").next().unwrap_or("").trim();
        if !home.is_empty() && !away.is_empty() {
            return Some((home.to_string(), away.to_string()));
        }
    }
    None
}

fn regex_lite_find(haystack: &str, pattern: &str) -> Option<(usize, usize)> {
    if pattern.contains("vs") {
        for sep in [" vs ", " VS ", " Vs ", " v ", " V ", " versus ", " Versus "] {
            if let Some(i) = haystack.find(sep) {
                return Some((i, i + sep.len()));
            }
        }
    }
    if pattern.contains("at|@") {
        for sep in [" at ", " At ", " @ ", " @"] {
            if let Some(i) = haystack.find(sep) {
                return Some((i, i + sep.len()));
            }
        }
    }
    None
}

fn team_match_tokens(team: &str) -> Vec<String> {
    let lower = team.trim().to_lowercase();
    if lower.is_empty() {
        return vec![];
    }
    let mut out = Vec::new();
    if lower.len() >= 4 {
        out.push(lower.clone());
    }
    for w in lower.split_whitespace() {
        if is_token(w) && !is_generic_team_token(w) {
            out.push(w.to_string());
        }
    }
    out.sort();
    out.dedup();
    out
}

fn is_word_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '\''
}

fn text_has_token(text_lower: &str, token: &str) -> bool {
    if token.is_empty() {
        return false;
    }
    let mut start = 0;
    while start + token.len() <= text_lower.len() {
        if let Some(rel) = text_lower[start..].find(token) {
            let abs = start + rel;
            let before_ok = abs == 0
                || !is_word_char(text_lower[..abs].chars().next_back().unwrap_or('\0'));
            let end = abs + token.len();
            let after_ok = end >= text_lower.len()
                || !is_word_char(text_lower[end..].chars().next().unwrap_or('\0'));
            if before_ok && after_ok {
                return true;
            }
            start = abs + 1;
        } else {
            break;
        }
    }
    false
}

fn count_token_hits(text_lower: &str, tokens: &[String]) -> usize {
    tokens
        .iter()
        .filter(|t| !t.is_empty() && text_has_token(text_lower, t.as_str()))
        .count()
}

/// Xtream folder names are short labels — substring match is OK there.
fn count_label_hits(label_lower: &str, tokens: &[String]) -> usize {
    tokens
        .iter()
        .filter(|t| !t.is_empty() && label_lower.contains(t.as_str()))
        .count()
}

fn matches_team_side(text_lower: &str, team: &str, tokens: &[String]) -> bool {
    let team_lower = team.trim().to_lowercase();
    if team_lower.len() >= 4 && text_has_token(text_lower, &team_lower) {
        return true;
    }
    tokens.iter().any(|k| text_has_token(text_lower, k))
}

fn has_4k(text_lower: &str) -> bool {
    text_has_token(text_lower, "4k")
}

struct EventScore {
    title_phrase_name: bool,
    title_phrase_epg: bool,
    specific_name: usize,
    specific_cat: usize,
    specific_epg: usize,
    sport_name: usize,
    sport_cat: usize,
}

impl EventScore {
    fn compute(game: &MatchGame, c: &Candidate) -> Self {
        let name = c.name.to_lowercase();
        let cat = c.category_label.to_lowercase();
        let epg = c.description.to_lowercase();
        Self {
            title_phrase_name: text_has_title_phrase(&name, &game.title_phrases),
            title_phrase_epg: text_has_title_phrase(&epg, &game.title_phrases),
            specific_name: count_token_hits(&name, &game.specific_tokens),
            specific_cat: count_label_hits(&cat, &game.specific_tokens),
            specific_epg: count_token_hits(&epg, &game.specific_tokens),
            sport_name: count_token_hits(&name, &game.sport_tokens),
            sport_cat: count_label_hits(&cat, &game.sport_tokens),
        }
    }

    fn specific_total(&self) -> usize {
        self.specific_name + self.specific_cat + self.specific_epg
    }

    fn pre_epg_rank(&self) -> i32 {
        let mut rank = 0i32;
        if self.title_phrase_name {
            rank += 50;
        }
        rank += (self.specific_name as i32) * 10;
        rank += (self.specific_cat as i32) * 8;
        rank += (self.sport_name as i32) * 4;
        rank += (self.sport_cat as i32) * 6;
        rank
    }

    fn tier(&self) -> Option<usize> {
        if self.title_phrase_name || self.title_phrase_epg {
            return Some(1);
        }
        let spec = self.specific_total();
        if spec >= 2 && (self.specific_name > 0 || self.specific_epg > 0) {
            return Some(1);
        }
        if self.specific_name >= 1 || self.specific_epg >= 1 {
            return Some(2);
        }
        if self.sport_cat >= 1 && (self.sport_name >= 1 || self.specific_epg >= 1) {
            return Some(3);
        }
        if spec >= 1 {
            return Some(4);
        }
        if self.sport_name >= 1 && self.sport_cat >= 1 {
            return Some(4);
        }
        None
    }
}

/// Pick at most `max` candidate indices to fetch short EPG for.
///
/// Prefers channels whose **name/category** already hint at the match.
/// For **team** games, pads up to `max` with the rest of the (category-filtered)
/// set so programme titles on ESPN / beIN / etc. can match when channel names
/// omit the teams. For **event** games (wrestling, F1, …), an empty name/sport
/// prefilter still returns nothing — avoids blind EPG scans of unrelated folders.
pub fn indices_for_epg(game: &MatchGame, candidates: &[Candidate], max: usize) -> Vec<usize> {
    if max == 0 || candidates.is_empty() {
        return vec![];
    }
    if candidates.len() <= max {
        return (0..candidates.len()).collect();
    }

    let mut scored: Vec<(usize, i32)> = Vec::new();
    for (i, c) in candidates.iter().enumerate() {
        let rank = if game.is_team_game() {
            team_prefilter_rank(game, c)
        } else {
            EventScore::compute(game, c).pre_epg_rank()
        };
        if rank > 0 {
            scored.push((i, rank));
        }
    }
    scored.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));

    let mut out = Vec::with_capacity(max);
    let mut taken = std::collections::HashSet::with_capacity(max);
    for (i, _) in scored.into_iter().take(max) {
        out.push(i);
        taken.insert(i);
    }

    if !game.is_team_game() {
        return out;
    }

    // Team games: fill remaining EPG budget so network channels can match via EPG.
    if out.len() < max {
        for i in 0..candidates.len() {
            if out.len() >= max {
                break;
            }
            if taken.insert(i) {
                out.push(i);
            }
        }
    }
    out
}

fn team_prefilter_rank(game: &MatchGame, c: &Candidate) -> i32 {
    let name = c.name.to_lowercase();
    let cat = c.category_label.to_lowercase();
    if text_has_title_phrase(&name, &game.title_phrases) {
        return 50;
    }
    let home = team_match_tokens(&game.home_team);
    let away = team_match_tokens(&game.away_team);
    let mut rank = 0i32;
    if matches_team_side(&name, &game.home_team, &home) {
        rank += 5;
    }
    if matches_team_side(&name, &game.away_team, &away) {
        rank += 5;
    }
    if matches_team_side(&cat, &game.home_team, &home) || matches_team_side(&cat, &game.away_team, &away)
    {
        rank += 2;
    }
    rank
}

fn match_event_streams(game: &MatchGame, candidates: &[Candidate]) -> Vec<Value> {
    if game.specific_tokens.is_empty() && game.sport_tokens.is_empty() {
        return vec![];
    }

    let mut tiers: [Vec<(usize, Option<f64>)>; 4] = [vec![], vec![], vec![], vec![]];

    for (idx, s) in candidates.iter().enumerate() {
        let score = EventScore::compute(game, s);
        let Some(tier) = score.tier() else {
            continue;
        };
        let combined = format!(
            "{} {} {}",
            s.name.to_lowercase(),
            s.category_label.to_lowercase(),
            s.description.to_lowercase()
        );
        if has_4k(&combined) && score.specific_total() >= 2 {
            tiers[0].push((idx, s.start_timestamp));
        } else {
            tiers[tier.saturating_sub(1)].push((idx, s.start_timestamp));
        }
    }

    sort_tiers_by_kickoff(game, &mut tiers);
    flatten_tiers(&tiers, candidates)
}

fn sort_tiers_by_kickoff(game: &MatchGame, tiers: &mut [Vec<(usize, Option<f64>)>; 4]) {
    let game_ts = if game.date_ms > 0 {
        Some(game.date_ms as f64 / 1000.0)
    } else {
        None
    };
    if let Some(gt) = game_ts {
        for tier in tiers.iter_mut() {
            tier.sort_by(|a, b| {
                let dist = |ts: Option<f64>| match ts {
                    Some(t) => (t - gt).abs(),
                    None => f64::INFINITY,
                };
                dist(a.1)
                    .partial_cmp(&dist(b.1))
                    .unwrap_or(std::cmp::Ordering::Equal)
            });
        }
    }
}

fn flatten_tiers(tiers: &[Vec<(usize, Option<f64>)>; 4], candidates: &[Candidate]) -> Vec<Value> {
    let mut out = Vec::new();
    let mut seen_ids = std::collections::HashSet::new();
    for (tier_idx, tier) in tiers.iter().enumerate() {
        for (idx, _) in tier {
            let s = &candidates[*idx];
            // Prefer stream_id dedupe (Stalker has empty URL until create_link).
            let key = if !s.stream_id.is_empty() {
                s.stream_id.clone()
            } else if !s.stream_url.is_empty() {
                s.stream_url.clone()
            } else {
                continue;
            };
            if !seen_ids.insert(key) {
                continue;
            }
            out.push(json!({
                "name": s.name,
                "title": s.category_label,
                "url": s.stream_url,
                "tier": tier_idx + 1,
                "stream_id": s.stream_id,
                "epg_channel_id": s.epg_channel_id,
                "logo": s.logo,
            }));
        }
    }
    out
}

/// Rank candidates; returns JSON stream items.
pub fn match_streams(
    game: &MatchGame,
    candidates: &[Candidate],
    all_team_names: &[String],
) -> Vec<Value> {
    if !game.is_team_game() {
        return match_event_streams(game, candidates);
    }
    let home_tokens = team_match_tokens(&game.home_team);
    let away_tokens = team_match_tokens(&game.away_team);
    let mut home_kw = home_tokens.clone();
    let mut away_kw = away_tokens.clone();
    let home_abbr = game.home_abbr.to_lowercase();
    let away_abbr = game.away_abbr.to_lowercase();
    if home_abbr.len() > 2 && !is_generic_team_token(&home_abbr) {
        home_kw.push(home_abbr.clone());
    }
    if away_abbr.len() > 2 && !is_generic_team_token(&away_abbr) {
        away_kw.push(away_abbr.clone());
    }

    let home_nick_tokens = team_match_tokens(&game.home_nick);
    let away_nick_tokens = team_match_tokens(&game.away_nick);

    let mut foreign_kw: std::collections::HashSet<String> = std::collections::HashSet::new();
    for name in all_team_names {
        for w in team_match_tokens(name) {
            foreign_kw.insert(w);
        }
    }
    for w in home_kw.iter().chain(away_kw.iter()) {
        foreign_kw.remove(w);
    }
    let foreign_list: Vec<String> = foreign_kw.into_iter().collect();

    let mut tiers: [Vec<(usize, Option<f64>)>; 4] = [vec![], vec![], vec![], vec![]];

    for (idx, s) in candidates.iter().enumerate() {
        let name = s.name.to_lowercase();
        let description = s.description.to_lowercase();
        let cat = s.category_label.to_lowercase();
        let combined = format!("{name} {description} {cat}");

        let home_in_name = matches_team_side(&name, &game.home_team, &home_tokens);
        let away_in_name = matches_team_side(&name, &game.away_team, &away_tokens);
        let home_in_desc = matches_team_side(&description, &game.home_team, &home_tokens);
        let away_in_desc = matches_team_side(&description, &game.away_team, &away_tokens);
        let home_in_cat = matches_team_side(&cat, &game.home_team, &home_tokens);
        let away_in_cat = matches_team_side(&cat, &game.away_team, &away_tokens);
        let both_in_either = (home_in_name || home_in_desc || home_in_cat)
            && (away_in_name || away_in_desc || away_in_cat);
        let both_in_name_alone = home_in_name && away_in_name;
        let both_in_desc_alone = home_in_desc && away_in_desc;

        if has_4k(&combined) && both_in_either {
            tiers[0].push((idx, s.start_timestamp));
            continue;
        }
        if text_has_title_phrase(&name, &game.title_phrases) {
            tiers[1].push((idx, s.start_timestamp));
            continue;
        }
        if text_has_title_phrase(&description, &game.title_phrases) {
            tiers[2].push((idx, s.start_timestamp));
            continue;
        }

        if both_in_name_alone && both_in_desc_alone {
            tiers[1].push((idx, s.start_timestamp));
            continue;
        }
        if both_in_either {
            tiers[2].push((idx, s.start_timestamp));
            continue;
        }
        if (matches_team_side(&name, &game.home_nick, &home_nick_tokens)
            || matches_team_side(&name, &game.away_nick, &away_nick_tokens))
            && !foreign_list
                .iter()
                .any(|w| text_has_token(&combined, w))
        {
            tiers[3].push((idx, s.start_timestamp));
        }
    }

    sort_tiers_by_kickoff(game, &mut tiers);
    flatten_tiers(&tiers, candidates)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn game() -> MatchGame {
        MatchGame {
            home_team: "Boston Red Sox".into(),
            away_team: "Toronto Blue Jays".into(),
            home_nick: "Red Sox".into(),
            away_nick: "Blue Jays".into(),
            home_abbr: "BOS".into(),
            away_abbr: "TOR".into(),
            title: "Boston Red Sox at Toronto Blue Jays".into(),
            specific_tokens: vec![],
            sport_tokens: tokenize_text("MLB"),
            title_phrases: build_title_phrases(
                "Boston Red Sox at Toronto Blue Jays",
                "Boston Red Sox",
                "Toronto Blue Jays",
            ),
            date_ms: 1_700_000_000_000,
        }
    }

    fn f1_game() -> MatchGame {
        MatchGame::from_json(&serde_json::json!({
            "title": "Dutch Grand Prix - Sprint",
            "sport": "motor-sports",
            "dateMs": 1_700_000_000_000i64
        }))
    }

    #[test]
    fn word_boundary_avoids_reds_false_positive() {
        let g = game();
        let league = vec![
            "Boston Red Sox".into(),
            "Toronto Blue Jays".into(),
            "Cincinnati Reds".into(),
            "Miami Marlins".into(),
        ];
        let cands = vec![Candidate {
            name: "Cincinnati Reds vs Miami Marlins".into(),
            description: "Reds at Marlins".into(),
            start_timestamp: None,
            stream_url: "https://x/1.m3u8".into(),
            category_label: "MLB".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &league);
        assert!(hits.is_empty(), "Reds channel must not match Red Sox game");
    }

    #[test]
    fn tier1_4k_both_teams() {
        let g = game();
        let cands = vec![Candidate {
            name: "Red Sox vs Blue Jays 4K".into(),
            description: "Boston Red Sox at Toronto Blue Jays".into(),
            start_timestamp: Some(1_700_000_000.0),
            stream_url: "https://x/4k.m3u8".into(),
            category_label: "MLB".into(),
            logo: "https://x/logo.png".into(),
            stream_id: "42".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].get("tier").and_then(|v| v.as_u64()), Some(1));
    }

    #[test]
    fn tier4_nickname_excludes_foreign() {
        let g = game();
        let league = vec![
            "Boston Red Sox".into(),
            "Toronto Blue Jays".into(),
            "New York Yankees".into(),
        ];
        let cands = vec![Candidate {
            name: "Red Sox Feed".into(),
            description: "Yankees highlights".into(),
            start_timestamp: None,
            stream_url: "https://x/nick.m3u8".into(),
            category_label: "MLB".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &league);
        assert!(hits.is_empty());
    }

    #[test]
    fn tier3_both_across_fields() {
        let g = game();
        let cands = vec![Candidate {
            name: "Red Sox Game".into(),
            description: "vs Blue Jays tonight".into(),
            start_timestamp: None,
            stream_url: "https://x/t3.m3u8".into(),
            category_label: "".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].get("tier").and_then(|v| v.as_u64()), Some(3));
    }

    #[test]
    fn epg_indices_prefer_name_hits_and_cap() {
        let g = game();
        let mut cands = Vec::new();
        for i in 0..200 {
            cands.push(Candidate {
                name: format!("News {i}"),
                description: String::new(),
                start_timestamp: None,
                stream_url: format!("https://x/{i}.m3u8"),
                category_label: "News".into(),
                logo: String::new(),
                stream_id: format!("{i}"),
                epg_channel_id: String::new(),
            });
        }
        cands[50].name = "Red Sox vs Blue Jays".into();
        cands[50].category_label = "MLB".into();

        let idxs = indices_for_epg(&g, &cands, 10);
        assert_eq!(idxs.len(), 10, "name hits first, then pad to EPG cap");
        assert_eq!(idxs[0], 50);
    }

    #[test]
    fn epg_indices_empty_name_prefilter_pads_to_cap() {
        let g = game();
        let mut cands = Vec::new();
        for i in 0..200 {
            cands.push(Candidate {
                name: format!("ESPN {i}"),
                description: String::new(),
                start_timestamp: None,
                stream_url: format!("https://x/{i}.m3u8"),
                category_label: "Sports".into(),
                logo: String::new(),
                stream_id: format!("{i}"),
                epg_channel_id: String::new(),
            });
        }
        let idxs = indices_for_epg(&g, &cands, 10);
        assert_eq!(idxs, (0..10).collect::<Vec<_>>());
    }

    #[test]
    fn epg_indices_small_set_returns_all() {
        let g = game();
        let cands = vec![Candidate {
            name: "A".into(),
            description: String::new(),
            start_timestamp: None,
            stream_url: "https://x/1.m3u8".into(),
            category_label: "".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        assert_eq!(indices_for_epg(&g, &cands, 120), vec![0]);
    }

    #[test]
    fn f1_title_matches_motorsport_channel_via_epg() {
        let g = f1_game();
        let cands = vec![
            Candidate {
                name: "Sky Sports F1 HD".into(),
                description: "Dutch Grand Prix Sprint".into(),
                start_timestamp: None,
                stream_url: "https://x/f1.m3u8".into(),
                category_label: "Motorsport".into(),
                logo: String::new(),
                stream_id: "1".into(),
                epg_channel_id: String::new(),
            },
            Candidate {
                name: "CNN News".into(),
                description: String::new(),
                start_timestamp: None,
                stream_url: "https://x/news.m3u8".into(),
                category_label: "News".into(),
                logo: String::new(),
                stream_id: "2".into(),
                epg_channel_id: String::new(),
            },
        ];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
        assert_eq!(
            hits[0].get("name").and_then(|v| v.as_str()),
            Some("Sky Sports F1 HD")
        );
    }

    #[test]
    fn f1_sport_folder_and_channel_name_without_epg() {
        let g = f1_game();
        let cands = vec![Candidate {
            name: "Sky Sports F1 HD".into(),
            description: String::new(),
            start_timestamp: None,
            stream_url: "https://x/f1.m3u8".into(),
            category_label: "Motorsport".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1, "sport folder + channel name must match");
    }

    #[test]
    fn f1_specific_token_in_channel_name() {
        let g = MatchGame::from_json(&serde_json::json!({
            "title": "F1 Dutch Grand Prix",
            "sport": "motor-sports",
            "dateMs": 1_700_000_000_000i64
        }));
        let cands = vec![Candidate {
            name: "NL F1 Dutch HD".into(),
            description: String::new(),
            start_timestamp: None,
            stream_url: "https://x/nl.m3u8".into(),
            category_label: "Racing".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
    }

    #[test]
    fn ppv_channel_name_with_full_event_title() {
        let g = f1_game();
        let cands = vec![Candidate {
            name: "PPV | Dutch Grand Prix Sprint HD".into(),
            description: String::new(),
            start_timestamp: None,
            stream_url: "https://x/ppv.m3u8".into(),
            category_label: "PPV Sports".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].get("tier").and_then(|v| v.as_u64()), Some(1));
    }

    #[test]
    fn ppv_team_match_in_channel_name() {
        let g = MatchGame::from_json(&serde_json::json!({
            "title": "Hull City vs Manchester United",
            "sport": "soccer",
            "homeTeam": "Hull City",
            "awayTeam": "Manchester United",
            "dateMs": 1_755_861_000_000i64
        }));
        let cands = vec![Candidate {
            name: "PPV: Hull City vs Manchester United".into(),
            description: String::new(),
            start_timestamp: None,
            stream_url: "https://x/ppv.m3u8".into(),
            category_label: "Football PPV".into(),
            logo: String::new(),
            stream_id: "1".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
    }

    #[test]
    fn hull_man_utd_must_not_match_birmingham_bristol_epg() {
        let g = MatchGame {
            home_team: "Hull City".into(),
            away_team: "Manchester United".into(),
            home_nick: "City".into(),
            away_nick: "United".into(),
            home_abbr: String::new(),
            away_abbr: String::new(),
            title: "Hull City vs Manchester United".into(),
            specific_tokens: build_event_tokens(
                "Hull City vs Manchester United",
                "soccer",
                "Hull City",
                "Manchester United",
            )
            .0,
            sport_tokens: tokenize_text("soccer"),
            title_phrases: build_title_phrases(
                "Hull City vs Manchester United",
                "Hull City",
                "Manchester United",
            ),
            date_ms: 1_755_861_000_000,
        };
        let cands = vec![Candidate {
            name: "Viaplay NO 07".into(),
            description: "Birmingham City vs Bristol City @ Aug 22 1:25 PM".into(),
            start_timestamp: Some(1_755_861_500.0),
            stream_url: "https://x/viaplay.m3u8".into(),
            category_label: "UK Football".into(),
            logo: String::new(),
            stream_id: "7".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert!(hits.is_empty(), "wrong EPG fixture must not match: {:?}", hits);
    }

    #[test]
    fn title_parses_teams_and_rejects_wrong_epg() {
        let g = MatchGame::from_json(&serde_json::json!({
            "title": "Hull City vs Manchester United",
            "sport": "soccer",
            "homeTeam": "",
            "awayTeam": "",
            "dateMs": 1_755_861_000_000i64
        }));
        assert!(g.is_team_game());
        let cands = vec![Candidate {
            name: "Viaplay NO 07".into(),
            description: "Birmingham City vs Bristol City @ Aug 22 1:25 PM".into(),
            start_timestamp: None,
            stream_url: "https://x/v.m3u8".into(),
            category_label: "UK Football".into(),
            logo: String::new(),
            stream_id: "7".into(),
            epg_channel_id: String::new(),
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert!(hits.is_empty());
    }

    #[test]
    fn wrestling_title_drops_year_token() {
        let g = MatchGame::from_json(&serde_json::json!({
            "title": "TNA Lockdown 2026",
            "sport": "Wrestling",
            "dateMs": 1_700_000_000_000i64
        }));
        assert!(!g.specific_tokens.contains(&"2026".to_string()));
        assert!(g.specific_tokens.contains(&"tna".to_string()));
        assert!(g.specific_tokens.contains(&"lockdown".to_string()));
    }

    #[test]
    fn wrestling_rejects_football_epg_year_only() {
        let g = MatchGame::from_json(&serde_json::json!({
            "title": "TNA Lockdown 2026",
            "sport": "Wrestling",
            "dateMs": 1_700_000_000_000i64
        }));
        let mut cands = Vec::new();
        for i in 0..200 {
            cands.push(Candidate {
                name: format!("Football Event {i}: Turkiye, 1. Lig"),
                description: format!("Live fixture @ Aug 22 2026 — channel {i}"),
                start_timestamp: None,
                stream_url: format!("https://x/{i}.m3u8"),
                category_label: "LIVE · Football".into(),
                logo: String::new(),
                stream_id: format!("{i}"),
                epg_channel_id: String::new(),
            });
        }
        let hits = match_streams(&g, &cands, &[]);
        assert!(hits.is_empty(), "year-only EPG must not match wrestling: {:?}", hits);
    }

    #[test]
    fn wrestling_matches_tna_channel_name() {
        let g = MatchGame::from_json(&serde_json::json!({
            "title": "TNA Lockdown 2026",
            "sport": "Wrestling",
            "dateMs": 1_700_000_000_000i64
        }));
        let cands = vec![
            Candidate {
                name: "Football Event 59: Turkiye".into(),
                description: "Some soccer @ 2026".into(),
                start_timestamp: None,
                stream_url: "https://x/soccer.m3u8".into(),
                category_label: "LIVE · Football".into(),
                logo: String::new(),
                stream_id: "1".into(),
                epg_channel_id: String::new(),
            },
            Candidate {
                name: "TNA+ PPV HD".into(),
                description: String::new(),
                start_timestamp: None,
                stream_url: "https://x/tna.m3u8".into(),
                category_label: "Wrestling".into(),
                logo: String::new(),
                stream_id: "2".into(),
                epg_channel_id: String::new(),
            },
        ];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
        assert_eq!(
            hits[0].get("name").and_then(|v| v.as_str()),
            Some("TNA+ PPV HD")
        );
    }

    #[test]
    fn epg_indices_empty_when_no_prefilter_hits() {
        let g = MatchGame::from_json(&serde_json::json!({
            "title": "TNA Lockdown 2026",
            "sport": "Wrestling",
            "dateMs": 1_700_000_000_000i64
        }));
        let cands: Vec<Candidate> = (0..200)
            .map(|i| Candidate {
                name: format!("Football Event {i}"),
                description: String::new(),
                start_timestamp: None,
                stream_url: format!("https://x/{i}.m3u8"),
                category_label: "LIVE · Football".into(),
                logo: String::new(),
                stream_id: format!("{i}"),
                epg_channel_id: String::new(),
            })
            .collect();
        let idxs = indices_for_epg(&g, &cands, 120);
        assert!(idxs.is_empty(), "must not EPG-scan unrelated channels");
    }
}
