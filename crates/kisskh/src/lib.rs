mod catalog;
mod http;
mod kkey;

use serde::Deserialize;
use serde_json::json;

pub use catalog::{
    enrich_card_descriptions, enrich_cards, enrich_home_feed, episode_page_url, explore,
    get_details, get_home, get_home_hero, get_home_rails, match_resume_episode,
    parse_card_list, search, slugify, year_from_release, KdramaCard, KdramaDetails, KdramaEpisode,
    KdramaExplorePage, KdramaHomeFeed,
};
pub use kkey::{generate_kkey, KkeyKind};

#[derive(Debug, Deserialize)]
struct CatalogRequest {
    action: String,
    #[serde(default)]
    query: String,
    #[serde(default = "default_page")]
    page: i32,
    #[serde(default)]
    type_filter: i32,
    #[serde(default)]
    sub: i32,
    #[serde(default)]
    country: i32,
    #[serde(default)]
    status: i32,
    #[serde(default = "default_order")]
    order: i32,
    #[serde(default = "default_page_size")]
    page_size: i32,
    #[serde(default)]
    id: i32,
    #[serde(default)]
    cards_json: String,
    #[serde(default)]
    feed_json: String,
    #[serde(default)]
    episode_number: f64,
    #[serde(default)]
    episode_id: i32,
    #[serde(default)]
    title: String,
    #[serde(default)]
    base_url: String,
}

fn default_page() -> i32 {
    1
}

fn default_order() -> i32 {
    1
}

fn default_page_size() -> i32 {
    40
}

pub fn catalog_json(request_json: &str) -> String {
    let req: CatalogRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    match req.action.as_str() {
        "home" => match get_home() {
            Ok(feed) => catalog::ok_json(&feed),
            Err(e) => catalog::error_json(&e),
        },
        "home_hero" => match get_home_hero() {
            Ok(feed) => catalog::ok_json(&feed),
            Err(e) => catalog::error_json(&e),
        },
        "home_rails" => match get_home_rails() {
            Ok(feed) => catalog::ok_json(&feed),
            Err(e) => catalog::error_json(&e),
        },
        "search" => match search(&req.query) {
            Ok(cards) => catalog::ok_json(&json!({ "cards": cards })),
            Err(e) => catalog::error_json(&e),
        },
        "explore" => match explore(
            req.page,
            req.type_filter,
            req.sub,
            req.country,
            req.status,
            req.order,
            req.page_size,
        ) {
            Ok(page) => catalog::ok_json(&page),
            Err(e) => catalog::error_json(&e),
        },
        "details" => match get_details(req.id) {
            Ok(details) => catalog::ok_json(&details),
            Err(e) => catalog::error_json(&e),
        },
        "enrich_cards" => {
            let cards: Vec<KdramaCard> = if req.cards_json.is_empty() {
                vec![]
            } else {
                serde_json::from_str(&req.cards_json).unwrap_or_default()
            };
            let enriched = enrich_cards(cards);
            catalog::ok_json(&json!({ "cards": enriched }))
        }
        "enrich_card_descriptions" => {
            let cards: Vec<KdramaCard> = if req.cards_json.is_empty() {
                vec![]
            } else {
                serde_json::from_str(&req.cards_json).unwrap_or_default()
            };
            let enriched = enrich_card_descriptions(cards);
            catalog::ok_json(&json!({ "cards": enriched }))
        }
        "enrich_home_feed" => {
            let feed: KdramaHomeFeed = if req.feed_json.is_empty() {
                KdramaHomeFeed {
                    spotlight: vec![],
                    latest: vec![],
                    most_viewed: vec![],
                    trending: vec![],
                    top_rated: vec![],
                    upcoming: vec![],
                    anime: vec![],
                }
            } else {
                serde_json::from_str(&req.feed_json).unwrap_or(KdramaHomeFeed {
                    spotlight: vec![],
                    latest: vec![],
                    most_viewed: vec![],
                    trending: vec![],
                    top_rated: vec![],
                    upcoming: vec![],
                    anime: vec![],
                })
            };
            let enriched = enrich_home_feed(feed);
            catalog::ok_json(&enriched)
        }
        "resolve_base_url" => match http::select_base_url() {
            Ok(base_url) => catalog::ok_json(&json!({
                "base_url": base_url,
                "mirror_urls": http::MIRROR_BASE_URLS,
            })),
            Err(e) => catalog::error_json(&e),
        },
        "probe_mirrors" => {
            let results = http::probe_mirrors();
            let mirrors: Vec<_> = results
                .iter()
                .map(|(base_url, healthy)| {
                    json!({
                        "base_url": base_url,
                        "healthy": healthy,
                    })
                })
                .collect();
            let healthy: Vec<_> = results
                .iter()
                .filter(|(_, ok)| *ok)
                .map(|(base, _)| base.clone())
                .collect();
            let selected = healthy.first().cloned().unwrap_or_default();
            if !selected.is_empty() {
                let _ = http::activate_base_url(&selected);
            }
            catalog::ok_json(&json!({
                "base_url": selected,
                "healthy_urls": healthy,
                "mirrors": mirrors,
            }))
        }
        "probe_one" => match http::probe_one(&req.base_url) {
            Ok((base_url, healthy)) => {
                if healthy {
                    let _ = http::activate_base_url(&base_url);
                }
                catalog::ok_json(&json!({
                    "base_url": base_url,
                    "healthy": healthy,
                }))
            }
            Err(e) => catalog::error_json(&e),
        },
        "activate_base_url" => match http::activate_base_url(&req.base_url) {
            Ok(base_url) => catalog::ok_json(&json!({ "base_url": base_url })),
            Err(e) => catalog::error_json(&e),
        },
        "slugify" => catalog::ok_json(&json!({ "slug": slugify(&req.title) })),
        "episode_page_url" => catalog::ok_json(&json!({
            "url": episode_page_url(req.id, &req.title, req.episode_id, req.episode_number)
        })),
        "match_resume_episode" => {
            let episodes: Vec<KdramaEpisode> =
                serde_json::from_str(&req.cards_json).unwrap_or_default();
            let episode_id = if req.episode_id > 0 {
                Some(req.episode_id)
            } else {
                None
            };
            let matched = match_resume_episode(&episodes, req.episode_number, episode_id);
            catalog::ok_json(&json!({ "episode": matched }))
        }
        "resolve_stream" => {
            let forced = req.base_url.trim();
            let forced = if forced.is_empty() { None } else { Some(forced) };
            match http::resolve_episode_stream(req.episode_id, forced) {
                Ok((base_url, episode, subtitles)) => catalog::ok_json(&json!({
                    "base_url": base_url,
                    "episode": episode,
                    "subtitles": subtitles,
                })),
                Err(e) => catalog::error_json(&e),
            }
        }
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = catalog_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }

    #[test]
    fn enrich_cards_roundtrip() {
        let cards = vec![KdramaCard {
            id: 1,
            title: "A".into(),
            cover: "".into(),
            label: None,
            episodes_count: 0,
            year: None,
            r#type: None,
            tmdb_id: None,
            description: String::new(),
        }];
        let req = json!({
            "action": "enrich_cards",
            "cards_json": serde_json::to_string(&cards).unwrap(),
        });
        let raw = catalog_json(&req.to_string());
        assert!(raw.contains("cards"));
    }
}
