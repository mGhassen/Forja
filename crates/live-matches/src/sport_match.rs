//! Sportio-style 4-tier IPTV channel ↔ game matcher.

use serde_json::{json, Value};

/// Normalized IPTV candidate (Xtream or M3U).
#[derive(Debug, Clone)]
pub struct Candidate {
    pub name: String,
    pub description: String,
    pub start_timestamp: Option<f64>,
    pub stream_url: String,
    pub category_label: String,
    /// Xtream `stream_icon` (channel logo URL).
    pub logo: String,
    /// Xtream `stream_id` — for catalog logo lookup on the host.
    pub stream_id: String,
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
        Self {
            home_team: s(v, "homeTeam"),
            away_team: s(v, "awayTeam"),
            home_nick: s(v, "homeNick"),
            away_nick: s(v, "awayNick"),
            home_abbr: s(v, "homeAbbr"),
            away_abbr: s(v, "awayAbbr"),
            date_ms,
        }
    }
}

fn keywords_from_name(name: &str) -> Vec<String> {
    name.to_lowercase()
        .split_whitespace()
        .filter(|w| w.len() > 2)
        .map(|w| w.to_string())
        .collect()
}

fn is_word_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '\''
}

/// Word-boundary substring match (Sportio `\b…\b` equivalent for ASCII keywords).
fn text_has_keyword(text_lower: &str, keyword_lower: &str) -> bool {
    if keyword_lower.is_empty() {
        return false;
    }
    let bytes = text_lower.as_bytes();
    let needle = keyword_lower.as_bytes();
    let mut start = 0;
    while start + needle.len() <= bytes.len() {
        if let Some(rel) = text_lower[start..].find(keyword_lower) {
            let abs = start + rel;
            let before_ok = abs == 0
                || !is_word_char(text_lower[..abs].chars().next_back().unwrap_or('\0'));
            let end = abs + keyword_lower.len();
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

fn matches_any(text_lower: &str, keywords: &[String]) -> bool {
    keywords.iter().any(|k| text_has_keyword(text_lower, k))
}

fn has_4k(text_lower: &str) -> bool {
    text_has_keyword(text_lower, "4k")
}

fn game_name_keywords(game: &MatchGame) -> Vec<String> {
    let mut kw = keywords_from_name(&game.home_team);
    kw.extend(keywords_from_name(&game.away_team));
    kw.extend(keywords_from_name(&game.home_nick));
    kw.extend(keywords_from_name(&game.away_nick));
    let home_abbr = game.home_abbr.to_lowercase();
    let away_abbr = game.away_abbr.to_lowercase();
    if home_abbr.len() > 2 {
        kw.push(home_abbr);
    }
    if away_abbr.len() > 2 {
        kw.push(away_abbr);
    }
    kw.sort();
    kw.dedup();
    kw
}

/// Channel name looks related to this game (cheap prefilter before short-EPG HTTP).
fn name_relevant_to_game(game: &MatchGame, channel_name: &str) -> bool {
    let name = channel_name.to_lowercase();
    matches_any(&name, &game_name_keywords(game))
}

fn looks_sports_label(text: &str) -> bool {
    let t = text.to_lowercase();
    const NEEDLES: &[&str] = &[
        "sport", "nba", "nfl", "mlb", "nhl", "ncaa", "soccer", "football",
        "basket", "hockey", "tennis", "golf", "ufc", "boxing", "racing",
        "f1", "moto", "cricket", "rugby", "espn", "bein", "sky sport",
        "dazn", "premier", "liga", "serie a", "bundesliga", "wnba",
    ];
    NEEDLES.iter().any(|n| t.contains(n))
}

/// Pick at most `max` candidate indices to fetch short EPG for.
/// Prefers name hits for this game, then sports-looking labels; never unbounded.
pub fn indices_for_epg(game: &MatchGame, candidates: &[Candidate], max: usize) -> Vec<usize> {
    if max == 0 || candidates.is_empty() {
        return vec![];
    }
    if candidates.len() <= max {
        return (0..candidates.len()).collect();
    }

    let mut scored: Vec<(usize, i32)> = Vec::with_capacity(candidates.len());
    for (i, c) in candidates.iter().enumerate() {
        let mut score = 0i32;
        if name_relevant_to_game(game, &c.name) {
            score += 10;
        }
        if looks_sports_label(&c.name) || looks_sports_label(&c.category_label) {
            score += 1;
        }
        if score > 0 {
            scored.push((i, score));
        }
    }
    scored.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    if scored.is_empty() {
        // No name/sports hint — still cap (do not EPG the whole bouquet).
        return (0..max).collect();
    }
    scored.truncate(max);
    scored.into_iter().map(|(i, _)| i).collect()
}

/// Rank candidates into Sportio tiers 1–4; returns JSON stream items.
pub fn match_streams(
    game: &MatchGame,
    candidates: &[Candidate],
    all_team_names: &[String],
) -> Vec<Value> {
    let mut home_kw = keywords_from_name(&game.home_team);
    let mut away_kw = keywords_from_name(&game.away_team);
    let home_abbr = game.home_abbr.to_lowercase();
    let away_abbr = game.away_abbr.to_lowercase();
    if home_abbr.len() > 2 {
        home_kw.push(home_abbr.clone());
    }
    if away_abbr.len() > 2 {
        away_kw.push(away_abbr.clone());
    }

    let mut home_nick_kw = keywords_from_name(&game.home_nick);
    let mut away_nick_kw = keywords_from_name(&game.away_nick);
    if home_abbr.len() > 2 {
        home_nick_kw.push(home_abbr);
    }
    if away_abbr.len() > 2 {
        away_nick_kw.push(away_abbr);
    }

    let mut foreign_kw: std::collections::HashSet<String> = std::collections::HashSet::new();
    for name in all_team_names {
        for w in keywords_from_name(name) {
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
        let combined = format!("{name} {description}");

        let home_in_name = matches_any(&name, &home_kw);
        let away_in_name = matches_any(&name, &away_kw);
        let home_in_desc = matches_any(&description, &home_kw);
        let away_in_desc = matches_any(&description, &away_kw);
        let both_in_either = (home_in_name || home_in_desc) && (away_in_name || away_in_desc);
        let both_in_name_alone = home_in_name && away_in_name;
        let both_in_desc_alone = home_in_desc && away_in_desc;

        if has_4k(&combined) && both_in_either {
            tiers[0].push((idx, s.start_timestamp));
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
        if matches_any(&name, &home_nick_kw) || matches_any(&name, &away_nick_kw) {
            if matches_any(&combined, &foreign_list) {
                continue;
            }
            tiers[3].push((idx, s.start_timestamp));
        }
    }

    let game_ts = if game.date_ms > 0 {
        Some(game.date_ms as f64 / 1000.0)
    } else {
        None
    };

    if let Some(gt) = game_ts {
        for tier in &mut tiers {
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

    let mut out = Vec::new();
    let mut seen_urls = std::collections::HashSet::new();
    for (tier_idx, tier) in tiers.iter().enumerate() {
        for (idx, _) in tier {
            let s = &candidates[*idx];
            if s.stream_url.is_empty() || !seen_urls.insert(s.stream_url.clone()) {
                continue;
            }
            // Channel name alone — category stays in `title` for UI chrome.
            out.push(json!({
                "name": s.name,
                "title": s.category_label,
                "url": s.stream_url,
                "tier": tier_idx + 1,
                "stream_id": s.stream_id,
                "logo": s.logo,
            }));
        }
    }
    out
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
            date_ms: 1_700_000_000_000,
        }
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
        }];
        let hits = match_streams(&g, &cands, &league);
        assert!(hits.is_empty(), "Reds channel must not match Red Sox game");
    }

    #[test]
    fn red_keyword_does_not_match_reds() {
        assert!(!text_has_keyword("cincinnati reds", "red"));
        assert!(text_has_keyword("boston red sox", "red"));
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
        }];
        let hits = match_streams(&g, &cands, &[]);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].get("tier").and_then(|v| v.as_u64()), Some(1));
        assert_eq!(
            hits[0].get("logo").and_then(|v| v.as_str()),
            Some("https://x/logo.png")
        );
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
            });
        }
        cands[50].name = "Red Sox vs Blue Jays".into();
        cands[50].category_label = "MLB".into();
        cands[90].name = "ESPN 8".into();
        cands[90].category_label = "Sports".into();

        let idxs = indices_for_epg(&g, &cands, 10);
        assert_eq!(idxs.len(), 2, "only name/sports-scored channels — no pad to max");
        assert_eq!(idxs[0], 50, "exact game name must rank first");
        assert!(idxs.contains(&90), "sports-looking label stays in cap");
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
        }];
        assert_eq!(indices_for_epg(&g, &cands, 120), vec![0]);
    }
}
