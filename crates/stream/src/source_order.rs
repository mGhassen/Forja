use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Maximum positions a provider may move from its settings baseline rank.
pub const MAX_PROVIDER_DISPLACEMENT: i32 = 2;

/// Cap how much live reliability can shift the domain sort input.
pub const RELIABILITY_ORDER_CLAMP: i32 = 20;

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
    /// Configured domain profile score (static).
    pub domain_score: u32,
    /// Sum of per-title reliability totals for this provider (across titles).
    #[serde(default)]
    pub reliability_score: i32,
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
    /// Live reliability totals keyed by provider id (optional; injected by FFI).
    #[serde(default)]
    pub reliability: HashMap<String, i32>,
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
            "vidsrcwin" => 69,
            "vidnest" => 65,
            "vidzee" => 60,
            "vidrock" => 55,
            "vidfast" => 58,
            "2embed" => 57,
            "autoembed" => 55,
            "vidlove" => 54,
            "vidsrcsbs" => 52,
            "111movies" => 54,
            "moviesapi" => 53,
            "webstreamr" => 50,
            _ => fallback_score(id, domain),
        },
        SourceDomain::Series => match id {
            "vidlink" => 92,
            "videasy" => 90,
            "service111477" => 85,
            "vixsrc" => 75,
            "vidsrc" => 70,
            "vidsrcwin" => 69,
            "vidnest" => 65,
            "vidzee" => 60,
            "vidrock" => 55,
            "vidfast" => 58,
            "2embed" => 57,
            "autoembed" => 55,
            "vidlove" => 54,
            "vidsrcsbs" => 52,
            "111movies" => 54,
            "moviesapi" => 53,
            "webstreamr" => 50,
            _ => fallback_score(id, domain),
        },
        SourceDomain::Anime => anime_score(id),
        SourceDomain::AsianDrama => match id {
            "kisskh" | "kisskh.co" => 99,
            "kisskh.nl" => 98,
            "kisskh.ovh" => 97,
            "kisskh.la" => 96,
            "kisskh.do" => 95,
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
        SourceDomain::AsianDrama if id.starts_with("kisskh.") => 1,
        _ => 0,
    }
}

fn supports_domain(id: &str, domain: SourceDomain) -> bool {
    domain_score(id, domain) > 0
}

fn ranking_score(
    id: &str,
    domain: SourceDomain,
    reliability: &HashMap<String, i32>,
) -> u32 {
    let base = domain_score(id, domain) as i32;
    let live = reliability
        .get(id)
        .copied()
        .unwrap_or(0)
        .clamp(-RELIABILITY_ORDER_CLAMP, RELIABILITY_ORDER_CLAMP);
    (base + live).clamp(0, 200) as u32
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
            | ("vidsrcwin", SourceDomain::Movies)
            | ("vidsrcwin", SourceDomain::Series)
            | ("vixsrc", SourceDomain::Movies)
            | ("vixsrc", SourceDomain::Series)
            | ("vidnest", SourceDomain::Movies)
            | ("vidnest", SourceDomain::Series)
            | ("vidzee", SourceDomain::Movies)
            | ("vidzee", SourceDomain::Series)
            | ("vidrock", SourceDomain::Movies)
            | ("vidrock", SourceDomain::Series)
            | ("vidfast", SourceDomain::Movies)
            | ("vidfast", SourceDomain::Series)
            | ("2embed", SourceDomain::Movies)
            | ("2embed", SourceDomain::Series)
            | ("autoembed", SourceDomain::Movies)
            | ("autoembed", SourceDomain::Series)
            | ("vidlove", SourceDomain::Movies)
            | ("vidlove", SourceDomain::Series)
            | ("vidsrcsbs", SourceDomain::Movies)
            | ("vidsrcsbs", SourceDomain::Series)
            | ("111movies", SourceDomain::Movies)
            | ("111movies", SourceDomain::Series)
            | ("moviesapi", SourceDomain::Movies)
            | ("moviesapi", SourceDomain::Series)
            | ("service111477", SourceDomain::Movies)
            | ("service111477", SourceDomain::Series)
            | ("webstreamr", SourceDomain::Movies)
            | ("webstreamr", SourceDomain::Series)
            | ("kisskh", SourceDomain::AsianDrama)
            | ("kisskh", SourceDomain::Anime)
            | ("kisskh.co", SourceDomain::AsianDrama)
            | ("kisskh.nl", SourceDomain::AsianDrama)
            | ("kisskh.ovh", SourceDomain::AsianDrama)
            | ("kisskh.la", SourceDomain::AsianDrama)
            | ("kisskh.do", SourceDomain::AsianDrama)
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
        "allanime:Yt-mp4",
        "allanime:S-mp4",
        "allanime:Luf-Mp4",
        "vidnest:hianime",
        "vidnest:animepahe",
        "megaplay",
        "vidwish",
        "miruro:zoro",
        "miruro:kiwi",
        "miruro:ally",
        "miruro:hop",
        "miruro:bonk",
        "miruro:moo",
        "miruro:animedunya",
        "miruro:arc",
        "miruro:jet",
        "miruro:bun",
        "miruro:kuz",
        "miruro:telli",
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
        || id.starts_with("vidnest:")
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
        let reliability_score = request.reliability.get(pin).copied().unwrap_or(0);
        return OrderProvidersResponse {
            ordered_ids: vec![pin.to_string()],
            rows: vec![ProviderOrderRow {
                id: pin.to_string(),
                settings_rank: settings_rank(pin, &request.settings_order, 0),
                domain_score: score,
                reliability_score,
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
        .map(|id| {
            (
                id.clone(),
                ranking_score(id, request.domain, &request.reliability),
            )
        })
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
                reliability_score: request.reliability.get(id).copied().unwrap_or(0),
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
        reliability: HashMap::new(),
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
            reliability: HashMap::new(),
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
            reliability: HashMap::new(),
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
            reliability: HashMap::new(),
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
            reliability: HashMap::new(),
        });
        assert_eq!(response.ordered_ids, vec!["nuvio:foo"]);
    }

    #[test]
    fn reliability_nudge_affects_score_rank_within_cap() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Movies,
            candidate_ids: vec!["webstreamr".into(), "moviesapi".into()],
            settings_order: vec!["webstreamr".into(), "moviesapi".into()],
            preferred: "auto".into(),
            reliability: HashMap::from([("moviesapi".into(), 20)]),
        });
        let moviesapi = response
            .rows
            .iter()
            .find(|r| r.id == "moviesapi")
            .unwrap();
        assert_eq!(moviesapi.reliability_score, 20);
        assert!(moviesapi.effective_rank <= 1);
    }

}
