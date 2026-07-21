use std::collections::{HashMap, HashSet};

use regex::Regex;
use serde::Serialize;
use serde_json::Value;

use crate::extractors::common::{anime_get, jaccard, tokenize};

const ANIKOTO_API: &str = "https://anikotoapi.site";
const ANIKOTO_TV: &str = "https://anikototv.to";

fn anikoto_api() -> String {
    utils::provider_runtime::api_base("anikotoApi")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| ANIKOTO_API.to_string())
}

fn anikoto_tv() -> String {
    utils::provider_runtime::api_base("anikotoTv")
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| ANIKOTO_TV.to_string())
}
const UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

const STOPWORDS: &[&str] = &[
    "the", "a", "an", "of", "and", "or", "to", "in", "on", "no", "wa", "ga", "ni", "wo", "de",
    "mo", "season", "part", "arc", "tv", "special", "ova", "ona",
];

#[derive(Debug, Clone, Serialize)]
pub struct AnikotoEpisodeOut {
    pub id: i64,
    pub number: i32,
    pub title: String,
    #[serde(rename = "embed_id")]
    pub embed_id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AnikotoSeriesOut {
    pub id: i64,
    #[serde(default)]
    pub slug: String,
    /// AniList id from Anikoto (may differ from Forja catalog — duplicate entries).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ani_id: Option<i64>,
    pub episodes: Vec<AnikotoEpisodeOut>,
}

#[derive(Debug, Clone)]
struct Candidate {
    slug: String,
    id: i64,
    episodes: i32,
}

fn json_headers() -> HashMap<String, String> {
    HashMap::from([
        ("Accept".into(), "application/json".into()),
        ("User-Agent".into(), UA.into()),
    ])
}

fn html_headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), UA.into()),
        ("Accept".into(), "text/html".into()),
    ])
}

fn anikoto_get(path: &str) -> Result<Value, String> {
    let url = format!("{}{path}", anikoto_api());
    let resp = anime_get(&url, &json_headers(), 15)?;
    if resp.status != 200 {
        return Err(format!("HTTP {}", resp.status));
    }
    let v: Value = serde_json::from_str(&resp.body).map_err(|e| e.to_string())?;
    if v.get("ok") == Some(&Value::Bool(false)) {
        return Err(v
            .get("error")
            .or_else(|| v.get("code"))
            .and_then(|x| x.as_str())
            .unwrap_or("anikoto error")
            .to_string());
    }
    Ok(v)
}

fn search_slugs(query: &str) -> Vec<String> {
    let q = query.trim();
    if q.is_empty() {
        return vec![];
    }
    let url = format!(
        "{}/search?keyword={}",
        anikoto_tv(),
        urlencoding::encode(q)
    );
    let Ok(resp) = anime_get(&url, &html_headers(), 15) else {
        return vec![];
    };
    if resp.status != 200 {
        return vec![];
    }
    let re = Regex::new(r"/watch/([a-z0-9-]+)").expect("watch slug regex");
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for cap in re.captures_iter(&resp.body) {
        if let Some(slug) = cap.get(1) {
            let s = slug.as_str().to_string();
            if seen.insert(s.clone()) {
                out.push(s);
                // Popular franchises bury the TV series under movies/OVAs
                // (Naruto TV is ~#21). Keep enough unique slugs to reach it.
                if out.len() >= 40 {
                    break;
                }
            }
        }
    }
    out
}

/// Movie/OVA/spin-off noise that Anikoto ranks above the main TV series.
fn slug_is_side_content(slug: &str) -> bool {
    const MARKERS: &[&str] = &[
        "movie",
        "ova",
        "ona",
        "special",
        "spin-off",
        "spinoff",
        "the-movie",
        "film",
        "recap",
        "summary",
    ];
    MARKERS.iter().any(|m| slug.contains(m))
}

/// AniList formats that *are* side content — do not demote special/ova slugs.
fn media_is_side_format(media_format: &str) -> bool {
    matches!(
        media_format.trim().to_ascii_uppercase().as_str(),
        "SPECIAL" | "OVA" | "ONA" | "MOVIE" | "MUSIC" | "TV_SHORT"
    )
}

/// Rank HTML search hits so exact title slugs are probed before movies.
/// Higher is better. Side-content slugs are heavily demoted for TV series.
fn slug_probe_score(slug: &str, title_tokens: &HashSet<String>, allow_side: bool) -> f64 {
    let tokens = slug_tokens(slug);
    if tokens.is_empty() || title_tokens.is_empty() {
        return if !allow_side && slug_is_side_content(slug) {
            -1.0
        } else {
            0.0
        };
    }
    let mut score = jaccard(&tokens, title_tokens);
    // Prefer slugs whose token set is close to the title (not "road of naruto").
    if tokens.is_subset(title_tokens) || title_tokens.is_subset(&tokens) {
        score += 0.35;
    }
    // Extra exactness: title tokens all appear and slug isn't much longer.
    if title_tokens.iter().all(|t| tokens.contains(t)) && tokens.len() <= title_tokens.len() + 1 {
        score += 0.25;
    }
    if !allow_side && slug_is_side_content(slug) {
        score -= 1.5;
    }
    score
}

fn id_from_slug(slug: &str) -> Option<i64> {
    let url = format!("{}/watch/{slug}", anikoto_tv());
    let resp = anime_get(&url, &html_headers(), 15).ok()?;
    if resp.status != 200 {
        return None;
    }
    let re = Regex::new(r#"data-id="(\d+)""#).ok()?;
    let cap = re.captures(&resp.body)?;
    cap.get(1)?.as_str().parse().ok()
}

fn series_from_json(anikoto_id: i64, j: &Value, slug: &str) -> AnikotoSeriesOut {
    let eps = j
        .pointer("/data/episodes")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let episodes = eps
        .iter()
        .filter_map(|e| {
            Some(AnikotoEpisodeOut {
                id: e.get("id")?.as_i64()?,
                number: e.get("number")?.as_i64()? as i32,
                title: e.get("title").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                embed_id: e
                    .get("episode_embed_id")
                    .map(|v| v.as_str().unwrap_or("").to_string())
                    .unwrap_or_default(),
            })
        })
        .collect();
    let ani_id = j
        .pointer("/data/anime/ani_id")
        .and_then(|v| v.as_str())
        .and_then(|s| s.parse::<i64>().ok())
        .filter(|&id| id > 0);
    AnikotoSeriesOut {
        id: anikoto_id,
        slug: slug.to_string(),
        ani_id,
        episodes,
    }
}

fn load_series(anikoto_id: i64, slug: &str) -> Result<AnikotoSeriesOut, String> {
    let j = anikoto_get(&format!("/series/{anikoto_id}"))?;
    Ok(series_from_json(anikoto_id, &j, slug))
}

fn slug_tokens(slug: &str) -> HashSet<String> {
    let hash_re = Regex::new(r"^[a-z0-9]{5}$").expect("hash token regex");
    slug.split('-')
        .filter(|t| t.len() > 1 && !hash_re.is_match(t))
        .flat_map(|t| tokenize(t, STOPWORDS))
        .collect()
}

/// Reject movie/OVA/special catalog hits when AniList expects a long series.
/// Half-of-expected allows airing / incomplete Anikoto catalogs.
fn episode_count_plausible(got: i32, expected: i32) -> bool {
    if got <= 0 {
        return false;
    }
    if expected <= 0 {
        return true;
    }
    got >= (expected as f64 / 2.0).ceil() as i32
}

fn pick_best_ani_id_match(cands: &mut [Candidate], expected: i32) -> Option<Candidate> {
    if cands.is_empty() {
        return None;
    }
    if expected > 0 {
        cands.sort_by(|a, b| {
            let da = (a.episodes - expected).abs();
            let db = (b.episodes - expected).abs();
            da.cmp(&db).then_with(|| b.episodes.cmp(&a.episodes))
        });
        let best = &cands[0];
        if !episode_count_plausible(best.episodes, expected) {
            return None;
        }
        Some(best.clone())
    } else {
        cands.sort_by(|a, b| b.episodes.cmp(&a.episodes));
        if episode_count_plausible(cands[0].episodes, expected) {
            Some(cands[0].clone())
        } else {
            None
        }
    }
}

pub fn anikoto_resolve(
    anilist_id: i64,
    title_candidates: &[String],
    expected_episodes: i32,
    media_format: &str,
) -> Result<Option<AnikotoSeriesOut>, String> {
    let ani_id = anilist_id.to_string();
    let allow_side = media_is_side_format(media_format);

    // Title search + a few ranked probes only. Do not crawl recent-anime
    // pages or hammer /watch HTML — that gets us blocked and stalls Play.
    // Caller orders candidates (romaji → english → native → synonyms).
    let mut queries = Vec::new();
    for q in title_candidates {
        let t = q.trim();
        if t.is_empty() {
            continue;
        }
        if !queries
            .iter()
            .any(|x: &String| x.eq_ignore_ascii_case(t))
        {
            queries.push(t.to_string());
        }
    }

    let mut title_tokens = HashSet::new();
    for q in &queries {
        title_tokens.extend(tokenize(q, STOPWORDS));
    }

    let mut candidates: Vec<String> = Vec::new();
    let mut seen = HashSet::new();
    for q in &queries {
        for slug in search_slugs(q) {
            if seen.insert(slug.clone()) {
                candidates.push(slug);
            }
        }
    }
    // Probe exact-title TV slugs first — Anikoto HTML search ranks movies
    // ahead of the main series (e.g. Naruto TV at rank 21).
    candidates.sort_by(|a, b| {
        slug_probe_score(b, &title_tokens, allow_side)
            .partial_cmp(&slug_probe_score(a, &title_tokens, allow_side))
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    // Cap hard: each probe is 2 HTTP (watch HTML + series JSON).
    const MAX_PROBE: usize = 6;
    let mut resolved = Vec::new();
    let mut ani_id_matches = Vec::new();
    let mut series_by_id: HashMap<i64, AnikotoSeriesOut> = HashMap::new();

    for slug in candidates.into_iter().take(MAX_PROBE) {
        let Some(id) = id_from_slug(&slug) else { continue };
        let Ok(j) = anikoto_get(&format!("/series/{id}")) else {
            continue;
        };
        let series = series_from_json(id, &j, &slug);
        let ep_count = series.episodes.len() as i32;
        series_by_id.insert(id, series);
        let found_ani = j
            .pointer("/data/anime/ani_id")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let cand = Candidate {
            slug: slug.clone(),
            id,
            episodes: ep_count,
        };
        if found_ani == ani_id {
            if episode_count_plausible(ep_count, expected_episodes) {
                return Ok(series_by_id.remove(&id));
            }
            ani_id_matches.push(cand);
        } else {
            resolved.push(cand);
        }
    }

    if let Some(best) = pick_best_ani_id_match(&mut ani_id_matches, expected_episodes) {
        if let Some(s) = series_by_id.remove(&best.id) {
            return Ok(Some(s));
        }
        return Ok(Some(load_series(best.id, &best.slug)?));
    }

    if !resolved.is_empty() && !title_tokens.is_empty() {
        let mut best: Option<&Candidate> = None;
        let mut best_score = 0.0_f64;
        for c in &resolved {
            if !episode_count_plausible(c.episodes, expected_episodes) {
                continue;
            }
            // Skip movie/OVA noise for long TV series — but keep it when
            // AniList itself is SPECIAL/OVA/… (e.g. Character Endings).
            if !allow_side && slug_is_side_content(&c.slug) && expected_episodes > 1 {
                continue;
            }
            let score = slug_probe_score(&c.slug, &title_tokens, allow_side);
            if score > best_score {
                best_score = score;
                best = Some(c);
            }
        }
        if let Some(c) = best {
            if best_score >= 0.40 {
                if let Some(s) = series_by_id.remove(&c.id) {
                    return Ok(Some(s));
                }
                return Ok(Some(load_series(c.id, &c.slug)?));
            }
        }
    }

    Ok(None)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slug_tokens_drop_hash_suffix() {
        let tokens = slug_tokens("jujutsu-kaisen-season-abc12");
        assert!(tokens.contains("jujutsu"));
        assert!(tokens.contains("kaisen"));
        assert!(!tokens.contains("abc12"));
    }

    #[test]
    fn pick_best_ani_id_prefers_episode_fit() {
        let mut cands = vec![
            Candidate {
                slug: "a".into(),
                id: 1,
                episodes: 1,
            },
            Candidate {
                slug: "b".into(),
                id: 2,
                episodes: 26,
            },
        ];
        assert_eq!(
            pick_best_ani_id_match(&mut cands, 26).map(|c| c.id),
            Some(2)
        );
    }

    #[test]
    fn episode_count_rejects_stub_vs_long_series() {
        assert!(!episode_count_plausible(1, 220));
        assert!(!episode_count_plausible(1, 26));
        assert!(episode_count_plausible(13, 26));
        assert!(episode_count_plausible(220, 220));
        assert!(episode_count_plausible(1, 0));
        assert!(!episode_count_plausible(0, 26));
    }

    #[test]
    fn pick_best_ani_id_rejects_all_stubs() {
        let mut cands = vec![
            Candidate {
                slug: "movie".into(),
                id: 1,
                episodes: 1,
            },
            Candidate {
                slug: "ova".into(),
                id: 2,
                episodes: 3,
            },
        ];
        assert!(pick_best_ani_id_match(&mut cands, 220).is_none());
    }

    #[test]
    fn slug_probe_prefers_main_series_over_movies() {
        let title = tokenize("Naruto", STOPWORDS);
        let tv = slug_probe_score("naruto-eybxz", &title, false);
        let movie = slug_probe_score("naruto-shippuuden-movie-6-road-to-ninja-w2wqq", &title, false);
        let road = slug_probe_score("road-of-naruto-ggjw8", &title, false);
        assert!(tv > movie, "tv={tv} movie={movie}");
        assert!(tv > road, "tv={tv} road={road}");
        assert!(slug_is_side_content("naruto-ova7-chunin-exam"));
        assert!(!slug_is_side_content("naruto-eybxz"));
    }

    #[test]
    fn special_format_does_not_demote_special_slugs() {
        let title = tokenize("Harukanaru Toki no Naka de Character Endings", STOPWORDS);
        let special = slug_probe_score(
            "harukanaru-toki-no-naka-de-hachiyou-shou-specials-abc12",
            &title,
            true,
        );
        let demoted = slug_probe_score(
            "harukanaru-toki-no-naka-de-hachiyou-shou-specials-abc12",
            &title,
            false,
        );
        assert!(special > demoted, "special={special} demoted={demoted}");
        assert!(media_is_side_format("SPECIAL"));
        assert!(media_is_side_format("ova"));
        assert!(!media_is_side_format("TV"));
    }
}
