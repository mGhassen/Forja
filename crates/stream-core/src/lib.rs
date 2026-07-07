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
        "vidzee" => Some(format!("https://vidzee.wtf/movie/{tmdb_id}")),
        "vidrock" => Some(format!("https://vidrock.net/movie/{tmdb_id}")),
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
            "https://vidzee.wtf/tv/{tmdb_id}/{season}/{episode}"
        )),
        "vidrock" => Some(format!(
            "https://vidrock.net/tv/{tmdb_id}/{season}/{episode}"
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
            Some("https://vidzee.wtf/movie/550".into())
        );
        assert_eq!(
            build_tv_url("vidzee", 1399, 2, 5),
            Some("https://vidzee.wtf/tv/1399/2/5".into())
        );
    }
}
