use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Maximum positions a provider may move from its settings baseline rank.
pub const MAX_PROVIDER_DISPLACEMENT: i32 = 2;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceDomain {
    Movies,
    Series,
    Anime,
    AsianDrama,
    Iptv,
    Torrent,
}

impl SourceDomain {
    pub fn parse(raw: &str) -> Option<Self> {
        match raw.trim().to_lowercase().as_str() {
            "movies" | "movie" => Some(Self::Movies),
            "series" | "tv" | "show" => Some(Self::Series),
            "anime" => Some(Self::Anime),
            "asian_drama" | "asian" | "drama" => Some(Self::AsianDrama),
            "iptv" => Some(Self::Iptv),
            "torrent" => Some(Self::Torrent),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProviderOrderRow {
    pub id: String,
    pub settings_rank: u32,
    pub domain_score: u32,
    pub effective_rank: u32,
    pub max_displacement: i32,
    pub supported: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OrderProvidersRequest {
    pub domain: SourceDomain,
    pub candidate_ids: Vec<String>,
    #[serde(default)]
    pub settings_order: Vec<String>,
    #[serde(default = "default_auto")]
    pub preferred: String,
}

fn default_auto() -> String {
    "auto".into()
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OrderProvidersResponse {
    pub ordered_ids: Vec<String>,
    pub rows: Vec<ProviderOrderRow>,
}

fn domain_score(id: &str, domain: SourceDomain) -> u32 {
    match domain {
        SourceDomain::Movies => match id {
            "videasy" => 95,
            "service111477" => 85,
            "vidlink" => 80,
            "vixsrc" => 75,
            "vidsrc" => 70,
            "vidnest" => 65,
            "vidzee" => 60,
            "vidrock" => 55,
            "webstreamr" => 50,
            _ => fallback_score(id, domain),
        },
        SourceDomain::Series => match id {
            "vidlink" => 92,
            "videasy" => 90,
            "service111477" => 85,
            "vixsrc" => 75,
            "vidsrc" => 70,
            "vidnest" => 65,
            "vidzee" => 60,
            "vidrock" => 55,
            "webstreamr" => 50,
            _ => fallback_score(id, domain),
        },
        SourceDomain::Anime => anime_score(id),
        SourceDomain::AsianDrama => match id {
            "kisskh" => 99,
            _ => fallback_score(id, domain),
        },
        SourceDomain::Iptv => match id {
            "xtream" => 95,
            "m3u" => 80,
            "stalker" => 70,
            _ => fallback_score(id, domain),
        },
        SourceDomain::Torrent => match id {
            "torrent" => 100,
            _ => fallback_score(id, domain),
        },
    }
}

fn fallback_score(id: &str, domain: SourceDomain) -> u32 {
    if known_profile(id, domain) {
        return 1;
    }
    match domain {
        SourceDomain::Movies | SourceDomain::Series if id.starts_with("nuvio:") => 1,
        SourceDomain::Anime if anime_score(id) > 0 => 1,
        _ => 0,
    }
}

fn supports_domain(id: &str, domain: SourceDomain) -> bool {
    domain_score(id, domain) > 0
}

fn known_profile(id: &str, domain: SourceDomain) -> bool {
    matches!(
        (id, domain),
        ("videasy", SourceDomain::Movies)
            | ("videasy", SourceDomain::Series)
            | ("vidlink", SourceDomain::Movies)
            | ("vidlink", SourceDomain::Series)
            | ("vidsrc", SourceDomain::Movies)
            | ("vidsrc", SourceDomain::Series)
            | ("vixsrc", SourceDomain::Movies)
            | ("vixsrc", SourceDomain::Series)
            | ("vidnest", SourceDomain::Movies)
            | ("vidnest", SourceDomain::Series)
            | ("vidzee", SourceDomain::Movies)
            | ("vidzee", SourceDomain::Series)
            | ("vidrock", SourceDomain::Movies)
            | ("vidrock", SourceDomain::Series)
            | ("service111477", SourceDomain::Movies)
            | ("service111477", SourceDomain::Series)
            | ("webstreamr", SourceDomain::Movies)
            | ("webstreamr", SourceDomain::Series)
            | ("kisskh", SourceDomain::AsianDrama)
            | ("kisskh", SourceDomain::Anime)
            | ("xtream", SourceDomain::Iptv)
            | ("m3u", SourceDomain::Iptv)
            | ("stalker", SourceDomain::Iptv)
            | ("torrent", SourceDomain::Torrent)
    ) || anime_score(id) > 0
}

fn anime_order() -> &'static [&'static str] {
    &[
        "miruro:bee",
        "allanime:Default",
        "allanime:S-mp4",
        "megaplay",
        "vidwish",
        "miruro:zoro",
        "animerealms:hianime",
        "miruro:kiwi",
        "animerealms:animepahe",
        "allanime:Yt-mp4",
        "allanime:Luf-Mp4",
        "allanime:Uv-mp4",
        "miruro:ally",
        "animerealms:allmanga",
        "miruro:hop",
        "miruro:bonk",
        "animerealms:gogoanime",
        "miruro:moo",
        "animerealms:zencloud",
        "animerealms:animekai",
        "animerealms:animez",
        "animerealms:kickassanime",
        "animerealms:anizone",
        "animerealms:febbox",
        "miruro:animedunya",
        "miruro:arc",
        "miruro:jet",
        "miruro:bun",
        "miruro:kuz",
        "miruro:telli",
        "animerealms:hanime-tv",
        "watchhentai",
        "hentaini",
    ]
}

fn anime_score(id: &str) -> u32 {
    for (i, key) in anime_order().iter().enumerate() {
        if *key == id {
            return (100 - i).max(1) as u32;
        }
    }
    if id.starts_with("miruro:")
        || id.starts_with("allanime:")
        || id.starts_with("animerealms:")
        || id == "megaplay"
        || id == "vidwish"
        || id == "watchhentai"
        || id == "hentaini"
    {
        1
    } else {
        0
    }
}

fn settings_rank(id: &str, settings_order: &[String], fallback_index: u32) -> u32 {
    for (i, key) in settings_order.iter().enumerate() {
        if key == id {
            return i as u32;
        }
    }
    fallback_index
}

pub fn order_providers(request: OrderProvidersRequest) -> OrderProvidersResponse {
    let mut candidates: Vec<String> = request
        .candidate_ids
        .iter()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty() && s != "auto")
        .collect();
    candidates.sort();
    candidates.dedup();

    if candidates.is_empty() {
        return OrderProvidersResponse {
            ordered_ids: vec![],
            rows: vec![],
        };
    }

    let pin = request.preferred.trim();
    if !pin.is_empty() && pin != "auto" {
        if !candidates.contains(&pin.to_string()) || !supports_domain(pin, request.domain) {
            return OrderProvidersResponse {
                ordered_ids: vec![],
                rows: vec![],
            };
        }
        let score = domain_score(pin, request.domain);
        return OrderProvidersResponse {
            ordered_ids: vec![pin.to_string()],
            rows: vec![ProviderOrderRow {
                id: pin.to_string(),
                settings_rank: settings_rank(pin, &request.settings_order, 0),
                domain_score: score,
                effective_rank: 0,
                max_displacement: MAX_PROVIDER_DISPLACEMENT,
                supported: true,
            }],
        };
    }

    let supported: Vec<String> = candidates
        .into_iter()
        .filter(|id| {
            let score = domain_score(id, request.domain);
            if score == 0 {
                return false;
            }
            if known_profile(id, request.domain) {
                return true;
            }
            // Unknown ids (Nuvio / unlisted mirrors) stay when caller scoped them.
            true
        })
        .collect();

    if supported.is_empty() {
        return OrderProvidersResponse {
            ordered_ids: vec![],
            rows: vec![],
        };
    }

    let mut baseline: HashMap<String, u32> = HashMap::new();
    for (i, id) in supported.iter().enumerate() {
        let rank = settings_rank(id, &request.settings_order, i as u32 + 10_000);
        baseline.insert(id.clone(), rank);
    }

    let mut score_rank: HashMap<String, u32> = HashMap::new();
    let mut by_score: Vec<(String, u32)> = supported
        .iter()
        .map(|id| (id.clone(), domain_score(id, request.domain)))
        .collect();
    by_score.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    for (i, (id, _)) in by_score.iter().enumerate() {
        score_rank.insert(id.clone(), i as u32);
    }

    let mut rows: Vec<ProviderOrderRow> = supported
        .iter()
        .map(|id| {
            let settings = *baseline.get(id).unwrap_or(&10_000);
            let score_based = *score_rank.get(id).unwrap_or(&10_000);
            let delta = score_based as i32 - settings as i32;
            let clamped_delta = delta.clamp(-MAX_PROVIDER_DISPLACEMENT, MAX_PROVIDER_DISPLACEMENT);
            let effective = (settings as i32 + clamped_delta).max(0) as u32;
            ProviderOrderRow {
                id: id.clone(),
                settings_rank: settings,
                domain_score: domain_score(id, request.domain),
                effective_rank: effective,
                max_displacement: MAX_PROVIDER_DISPLACEMENT,
                supported: true,
            }
        })
        .collect();

    rows.sort_by(|a, b| {
        a.effective_rank
            .cmp(&b.effective_rank)
            .then_with(|| a.settings_rank.cmp(&b.settings_rank))
            .then_with(|| a.id.cmp(&b.id))
    });

    let ordered_ids: Vec<String> = rows.iter().map(|r| r.id.clone()).collect();
    OrderProvidersResponse {
        ordered_ids,
        rows,
    }
}

pub fn next_provider_ids(
    domain: SourceDomain,
    candidate_ids: &[String],
    current_id: &str,
    settings_order: &[String],
) -> Vec<String> {
    let response = order_providers(OrderProvidersRequest {
        domain,
        candidate_ids: candidate_ids.to_vec(),
        settings_order: settings_order.to_vec(),
        preferred: "auto".into(),
    });
    let cur = current_id.trim();
    if cur.is_empty() {
        return response.ordered_ids;
    }
    let idx = response.ordered_ids.iter().position(|id| id == cur);
    match idx {
        None => response.ordered_ids,
        Some(i) if i + 1 >= response.ordered_ids.len() => vec![],
        Some(i) => response.ordered_ids[i + 1..].to_vec(),
    }
}

pub fn order_providers_json(payload_json: &str) -> String {
    let request: OrderProvidersRequest = match serde_json::from_str(payload_json) {
        Ok(r) => r,
        Err(e) => return serde_json::json!({ "error": e.to_string() }).to_string(),
    };
    let response = order_providers(request);
    serde_json::to_string(&response).unwrap_or_else(|e| {
        serde_json::json!({ "error": e.to_string() }).to_string()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn settings_baseline_with_bounded_domain_adjustment() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Movies,
            candidate_ids: vec!["vidsrc".into(), "vixsrc".into()],
            settings_order: vec!["vidsrc".into(), "vixsrc".into()],
            preferred: "auto".into(),
        });
        assert_eq!(response.ordered_ids.len(), 2);
        let vidsrc = response.rows.iter().find(|r| r.id == "vidsrc").unwrap();
        let vixsrc = response.rows.iter().find(|r| r.id == "vixsrc").unwrap();
        assert_eq!(vidsrc.settings_rank, 0);
        assert_eq!(vixsrc.settings_rank, 1);
        // vixsrc has higher domain score but can move at most +2 from baseline.
        assert!(vixsrc.effective_rank <= vidsrc.effective_rank + 2);
    }

    #[test]
    fn strict_pin_single_provider() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::AsianDrama,
            candidate_ids: vec!["kisskh".into()],
            settings_order: vec![],
            preferred: "kisskh".into(),
        });
        assert_eq!(response.ordered_ids, vec!["kisskh"]);
        assert_eq!(response.rows.len(), 1);
    }

    #[test]
    fn cross_domain_exclusion() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Anime,
            candidate_ids: vec!["videasy".into(), "miruro:bee".into()],
            settings_order: vec![],
            preferred: "auto".into(),
        });
        assert_eq!(response.ordered_ids, vec!["miruro:bee"]);
    }

    #[test]
    fn next_provider_after_current() {
        let next = next_provider_ids(
            SourceDomain::Movies,
            &[
                "webstreamr".into(),
                "videasy".into(),
                "vidnest".into(),
            ],
            "videasy",
            &[],
        );
        assert!(!next.contains(&"videasy".to_string()));
        assert!(!next.is_empty());
    }

    #[test]
    fn unknown_nuvio_ids_follow_settings_order() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Movies,
            candidate_ids: vec!["nuvio:foo".into()],
            settings_order: vec!["nuvio:foo".into()],
            preferred: "auto".into(),
        });
        assert_eq!(response.ordered_ids, vec!["nuvio:foo"]);
    }
}
