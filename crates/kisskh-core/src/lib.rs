mod catalog;
mod http;

use serde::Deserialize;
use serde_json::json;

pub use catalog::{
    enrich_cards, enrich_home_feed, episode_page_url, explore, get_details, get_home, match_resume_episode,
    parse_card_list, search, slugify, year_from_release, KdramaCard, KdramaDetails, KdramaEpisode,
    KdramaExplorePage, KdramaHomeFeed,
};

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
        }];
        let req = json!({
            "action": "enrich_cards",
            "cards_json": serde_json::to_string(&cards).unwrap(),
        });
        let raw = catalog_json(&req.to_string());
        assert!(raw.contains("cards"));
    }
}
