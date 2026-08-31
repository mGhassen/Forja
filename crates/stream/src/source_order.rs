//! Provider try-order: **settings list first**, then remaining candidates.
//!
//! No built-in embed / sniff domain profiles — those retired with the legacy
//! green-Play resolver. Reliability totals (optional) may nudge ±2 ranks.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Maximum positions a provider may move from its settings baseline rank.
pub const MAX_PROVIDER_DISPLACEMENT: i32 = 2;

/// Cap how much live reliability can shift the sort input.
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
    /// Unused (kept for JSON shape / Dart). Always 1 when supported.
    pub domain_score: u32,
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

fn settings_rank(id: &str, settings_order: &[String], fallback_index: u32) -> u32 {
    for (i, key) in settings_order.iter().enumerate() {
        if key == id {
            return i as u32;
        }
    }
    fallback_index
}

fn reliability_nudge(id: &str, reliability: &HashMap<String, i32>) -> i32 {
    reliability
        .get(id)
        .copied()
        .unwrap_or(0)
        .clamp(-RELIABILITY_ORDER_CLAMP, RELIABILITY_ORDER_CLAMP)
}

/// Order candidates: settings order, then leftovers. Optional reliability ±2 nudge.
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
        if !candidates.iter().any(|c| c == pin) {
            return OrderProvidersResponse {
                ordered_ids: vec![],
                rows: vec![],
            };
        }
        let reliability_score = request.reliability.get(pin).copied().unwrap_or(0);
        return OrderProvidersResponse {
            ordered_ids: vec![pin.to_string()],
            rows: vec![ProviderOrderRow {
                id: pin.to_string(),
                settings_rank: settings_rank(pin, &request.settings_order, 0),
                domain_score: 1,
                reliability_score,
                effective_rank: 0,
                max_displacement: MAX_PROVIDER_DISPLACEMENT,
                supported: true,
            }],
        };
    }

    // Baseline: settings_order first, then remaining candidates (stable alpha).
    let mut ordered: Vec<String> = Vec::with_capacity(candidates.len());
    let mut seen = std::collections::HashSet::new();
    for id in &request.settings_order {
        let id = id.trim();
        if id.is_empty() || id == "auto" {
            continue;
        }
        if candidates.iter().any(|c| c == id) && seen.insert(id.to_string()) {
            ordered.push(id.to_string());
        }
    }
    let mut rest: Vec<String> = candidates
        .into_iter()
        .filter(|id| !seen.contains(id))
        .collect();
    rest.sort();
    ordered.extend(rest);

    let mut baseline: HashMap<String, u32> = HashMap::new();
    for (i, id) in ordered.iter().enumerate() {
        baseline.insert(id.clone(), i as u32);
    }

    let any_reliability = ordered
        .iter()
        .any(|id| reliability_nudge(id, &request.reliability) != 0);

    let rel_rank: HashMap<String, u32> = if any_reliability {
        let mut by_rel: Vec<(String, i32)> = ordered
            .iter()
            .map(|id| (id.clone(), reliability_nudge(id, &request.reliability)))
            .collect();
        by_rel.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
        by_rel
            .into_iter()
            .enumerate()
            .map(|(i, (id, _))| (id, i as u32))
            .collect()
    } else {
        HashMap::new()
    };

    let mut rows: Vec<ProviderOrderRow> = ordered
        .iter()
        .map(|id| {
            let settings = *baseline.get(id).unwrap_or(&10_000);
            let effective = if !any_reliability {
                settings
            } else {
                let rel_based = *rel_rank.get(id).unwrap_or(&10_000);
                let delta = rel_based as i32 - settings as i32;
                let clamped = delta.clamp(-MAX_PROVIDER_DISPLACEMENT, MAX_PROVIDER_DISPLACEMENT);
                (settings as i32 + clamped).max(0) as u32
            };
            ProviderOrderRow {
                id: id.clone(),
                settings_rank: settings,
                domain_score: 1,
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
    fn settings_order_wins() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Movies,
            candidate_ids: vec!["b".into(), "a".into(), "c".into()],
            settings_order: vec!["c".into(), "a".into()],
            preferred: "auto".into(),
            reliability: HashMap::new(),
        });
        assert_eq!(response.ordered_ids, vec!["c", "a", "b"]);
    }

    #[test]
    fn unknown_plugin_ids_are_kept() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Movies,
            candidate_ids: vec!["engine-plugin-x".into(), "videasy".into()],
            settings_order: vec!["engine-plugin-x".into()],
            preferred: "auto".into(),
            reliability: HashMap::new(),
        });
        assert_eq!(response.ordered_ids[0], "engine-plugin-x");
        assert!(response.ordered_ids.contains(&"videasy".to_string()));
    }

    #[test]
    fn strict_pin() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Anime,
            candidate_ids: vec!["megaplay".into(), "anikoto".into()],
            settings_order: vec![],
            preferred: "anikoto".into(),
            reliability: HashMap::new(),
        });
        assert_eq!(response.ordered_ids, vec!["anikoto"]);
    }

    #[test]
    fn next_provider_after_current() {
        let next = next_provider_ids(
            SourceDomain::Movies,
            &["a".into(), "b".into(), "c".into()],
            "b",
            &["a".into(), "b".into(), "c".into()],
        );
        assert_eq!(next, vec!["c"]);
    }

    #[test]
    fn reliability_nudge_within_cap() {
        let response = order_providers(OrderProvidersRequest {
            domain: SourceDomain::Movies,
            candidate_ids: vec!["a".into(), "b".into()],
            settings_order: vec!["a".into(), "b".into()],
            preferred: "auto".into(),
            reliability: HashMap::from([("b".into(), 20), ("a".into(), 0)]),
        });
        let a = response.rows.iter().find(|r| r.id == "a").unwrap();
        let b = response.rows.iter().find(|r| r.id == "b").unwrap();
        assert!(b.effective_rank <= a.effective_rank + 2);
    }
}
