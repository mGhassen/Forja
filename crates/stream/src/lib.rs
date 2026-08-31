mod normalize;
mod playable;
mod select;
mod source_order;

pub use normalize::from_legacy;
pub use playable::*;
pub use select::{normalize_legacy_json, rank_sources, rank_sources_json};
pub use source_order::{
    order_providers, order_providers_json, next_provider_ids, OrderProvidersRequest,
    OrderProvidersResponse, ProviderOrderRow, SourceDomain, MAX_PROVIDER_DISPLACEMENT,
    RELIABILITY_ORDER_CLAMP,
};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProviderDef {
    pub id: String,
    pub name: String,
    pub has_movie_template: bool,
    pub has_tv_template: bool,
}

/// Built-in movie/TV embed templates retired — engine JS providers only.
pub fn list_providers() -> Vec<ProviderDef> {
    vec![]
}

pub fn build_movie_url(provider_id: &str, tmdb_id: i64) -> Option<String> {
    let tpl = utils::provider_runtime::movie_template(provider_id)?;
    Some(utils::provider_runtime::expand_template(&tpl, tmdb_id, 0, 0))
}

pub fn build_tv_url(provider_id: &str, tmdb_id: i64, season: i32, episode: i32) -> Option<String> {
    let tpl = utils::provider_runtime::tv_template(provider_id)?;
    Some(utils::provider_runtime::expand_template(
        &tpl, tmdb_id, season, episode,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unknown_provider_returns_none() {
        utils::provider_runtime::clear_overlay();
        assert_eq!(build_movie_url("vidlink", 550), None);
    }

    #[test]
    fn overlay_movie_template() {
        utils::provider_runtime::clear_overlay();
        utils::provider_runtime::set_overlay_json(
            r#"{
              "schema": 1,
              "templates": {
                "vidlink": { "movie": "https://ops.test/movie/{tmdb}" }
              }
            }"#,
        )
        .unwrap();
        assert_eq!(
            build_movie_url("vidlink", 550),
            Some("https://ops.test/movie/550".into())
        );
        utils::provider_runtime::clear_overlay();
    }
}
