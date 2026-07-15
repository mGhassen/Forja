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

pub fn list_providers() -> Vec<ProviderDef> {
    vec![
        ProviderDef {
            id: "service111477".into(),
            name: "111477.xyz".into(),
            has_movie_template: false,
            has_tv_template: false,
        },
        ProviderDef {
            id: "webstreamr".into(),
            name: "WebStreamr".into(),
            has_movie_template: false,
            has_tv_template: false,
        },
        ProviderDef {
            id: "vidlink".into(),
            name: "VidLink".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "vixsrc".into(),
            name: "VixSrc".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "vidnest".into(),
            name: "VidNest".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "vidzee".into(),
            name: "Vidzee".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "vidrock".into(),
            name: "VidRock".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "vidfast".into(),
            name: "VidFast".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "2embed".into(),
            name: "2Embed".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "autoembed".into(),
            name: "AutoEmbed".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "vidlove".into(),
            name: "VidLove".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "vidsrcsbs".into(),
            name: "VidSrc.sbs".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "111movies".into(),
            name: "111Movies".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "moviesapi".into(),
            name: "MoviesAPI".into(),
            has_movie_template: true,
            has_tv_template: true,
        },
        ProviderDef {
            id: "videasy".into(),
            name: "Videasy".into(),
            has_movie_template: false,
            has_tv_template: false,
        },
        ProviderDef {
            id: "vidsrc".into(),
            name: "Vidsrc".into(),
            has_movie_template: false,
            has_tv_template: false,
        },
    ]
}

pub fn build_movie_url(provider_id: &str, tmdb_id: i64) -> Option<String> {
    match provider_id {
        "vidlink" => Some(format!("https://vidlink.pro/movie/{tmdb_id}")),
        "vixsrc" => Some(format!("https://vixsrc.to/movie/{tmdb_id}/")),
        "vidnest" => Some(format!("https://vidnest.fun/movie/{tmdb_id}")),
        "vidzee" => Some(format!(
            "https://player.vidzee.wtf/embed/movie/{tmdb_id}"
        )),
        "vidrock" => Some(format!("https://vidrock.ru/movie/{tmdb_id}")),
        "vidfast" => Some(format!(
            "https://vidfast.vc/movie/{tmdb_id}?autoPlay=true"
        )),
        // Canonical host per https://www.2embed.online/ — .online 301s here.
        // Legacy www.2embed.cc redirects top-level loads to .skin and breaks sniff.
        "2embed" => Some(format!("https://2embed.stream/embed/movie/{tmdb_id}")),
        // Player host as top-level — outer autoembed.co iframes this URL; nested
        // loads hit sandbox/"Playback blocked" (asb.html) in headless WebView.
        "autoembed" => Some(format!(
            "https://player.autoembed.co/embed/movie/{tmdb_id}"
        )),
        "vidlove" => Some(format!("https://player.vidlove.cc/embed/movie/{tmdb_id}")),
        "vidsrcsbs" => Some(format!("https://vidsrc.sbs/embed/movie/{tmdb_id}")),
        "111movies" => Some(format!("https://player.vidlove.cc/embed/movie/{tmdb_id}")),
        "moviesapi" => Some(format!("https://moviesapi.to/movie/{tmdb_id}")),
        _ => None,
    }
}

pub fn build_tv_url(provider_id: &str, tmdb_id: i64, season: i32, episode: i32) -> Option<String> {
    match provider_id {
        "vidlink" => Some(format!(
            "https://vidlink.pro/tv/{tmdb_id}/{season}/{episode}"
        )),
        "vixsrc" => Some(format!(
            "https://vixsrc.to/tv/{tmdb_id}/{season}/{episode}/"
        )),
        "vidnest" => Some(format!(
            "https://vidnest.fun/tv/{tmdb_id}/{season}/{episode}"
        )),
        "vidzee" => Some(format!(
            "https://player.vidzee.wtf/embed/tv/{tmdb_id}/{season}/{episode}"
        )),
        "vidrock" => Some(format!(
            "https://vidrock.ru/tv/{tmdb_id}/{season}/{episode}"
        )),
        "vidfast" => Some(format!(
            "https://vidfast.vc/tv/{tmdb_id}/{season}/{episode}?autoPlay=true"
        )),
        "2embed" => Some(format!(
            "https://2embed.stream/embed/tv/{tmdb_id}/{season}/{episode}"
        )),
        "autoembed" => Some(format!(
            "https://player.autoembed.co/embed/tv/{tmdb_id}/{season}-{episode}/"
        )),
        "vidlove" => Some(format!(
            "https://player.vidlove.cc/embed/tv/{tmdb_id}/{season}/{episode}"
        )),
        "vidsrcsbs" => Some(format!(
            "https://vidsrc.sbs/embed/tv/{tmdb_id}/{season}/{episode}"
        )),
        "111movies" => Some(format!(
            "https://player.vidlove.cc/embed/tv/{tmdb_id}/{season}/{episode}"
        )),
        "moviesapi" => Some(format!(
            "https://moviesapi.to/tv/{tmdb_id}-{season}-{episode}"
        )),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vidlink_movie_url() {
        assert_eq!(
            build_movie_url("vidlink", 550),
            Some("https://vidlink.pro/movie/550".into())
        );
    }

    #[test]
    fn vidnest_movie_url() {
        assert_eq!(
            build_movie_url("vidnest", 99),
            Some("https://vidnest.fun/movie/99".into())
        );
    }

    #[test]
    fn vidlink_tv_url() {
        assert_eq!(
            build_tv_url("vidlink", 1399, 2, 5),
            Some("https://vidlink.pro/tv/1399/2/5".into())
        );
    }

    #[test]
    fn unknown_provider_returns_none() {
        assert_eq!(build_movie_url("unknown", 1), None);
    }

    #[test]
    fn vidzee_urls() {
        assert_eq!(
            build_movie_url("vidzee", 550),
            Some("https://player.vidzee.wtf/embed/movie/550".into())
        );
        assert_eq!(
            build_tv_url("vidzee", 1399, 2, 5),
            Some("https://player.vidzee.wtf/embed/tv/1399/2/5".into())
        );
    }

    #[test]
    fn vidfast_urls() {
        assert_eq!(
            build_movie_url("vidfast", 550),
            Some("https://vidfast.vc/movie/550?autoPlay=true".into())
        );
        assert_eq!(
            build_tv_url("vidfast", 1399, 2, 5),
            Some("https://vidfast.vc/tv/1399/2/5?autoPlay=true".into())
        );
    }

    #[test]
    fn twoembed_urls() {
        assert_eq!(
            build_movie_url("2embed", 550),
            Some("https://2embed.stream/embed/movie/550".into())
        );
        assert_eq!(
            build_tv_url("2embed", 1399, 2, 5),
            Some("https://2embed.stream/embed/tv/1399/2/5".into())
        );
    }

    #[test]
    fn vidsrcsbs_urls() {
        assert_eq!(
            build_movie_url("vidsrcsbs", 550),
            Some("https://vidsrc.sbs/embed/movie/550".into())
        );
        assert_eq!(
            build_tv_url("vidsrcsbs", 1399, 2, 5),
            Some("https://vidsrc.sbs/embed/tv/1399/2/5".into())
        );
    }
}
