use super::{
    parse_source_html, resolve_source, series_title, SourceEmbed, SourceRequest,
};
use crate::config::{self, Config};
use crate::fetcher::{
    fetch_head, fetch_json, fetch_text, fetch_text_post, final_redirect_url, FetchConfig,
};
use crate::utils::resolve_redirect_url;
use crate::tmdb::{get_tmdb_name_and_year, resolve_ids, MediaIds};
use crate::types::MediaType;
use regex::Regex;
use scraper::{ElementRef, Html, Selector};
use std::collections::HashMap;
use std::sync::LazyLock;

static VEGAMOVIES_SEASON_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\bS\d{1,2}\b").unwrap());
static KOKOSHKA_TITLE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\(\d+\).*").unwrap());

#[derive(Debug, Clone)]
pub struct SourceDef {
    pub id: &'static str,
    pub label: &'static str,
    pub content_types: &'static [MediaType],
    pub country_codes: &'static [&'static str],
    pub base_url: &'static str,
    pub priority: i32,
    pub use_only_with_max_urls_found: Option<i32>,
}

/// Bases aligned with WebStreamrMBG `src/source` (2026-07).
/// Legacy Forja-only sources (`rgshows`, `streamkiste`, `vegamovies`) kept.
pub const ALL_SOURCES: &[SourceDef] = &[
    SourceDef {
        id: "4khdhub",
        label: "4KHDHub",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi", "hi", "ta", "te"],
        base_url: "https://4khdhub.link",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "hdhub4u",
        label: "HDHub4u",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi", "gu", "hi", "ml", "pa", "ta", "te"],
        base_url: "https://new1.hdhub4u.af",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "vixsrc",
        label: "VixSrc",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi"],
        base_url: "https://vixsrc.to",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "vidsrc",
        label: "VidSrc",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi"],
        base_url: "https://vidsrcme.ru",
        priority: 0,
        use_only_with_max_urls_found: Some(0),
    },
    SourceDef {
        id: "vidzee",
        label: "VidZee",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi"],
        base_url: "https://player.vidzee.wtf",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "moviebox",
        label: "MovieBox",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi"],
        base_url: "https://moviebox.ph",
        priority: -1,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "rgshows",
        label: "RGShows",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi"],
        base_url: "https://rgshows.ru",
        priority: -1,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "kokoshka",
        label: "Kokoshka",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["al"],
        base_url: "https://kokoshka.digital",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "cinehdplus",
        label: "CineHDPlus",
        content_types: &[MediaType::Series],
        country_codes: &["es", "mx"],
        base_url: "https://cinehdplus.zone",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "cuevana",
        label: "Cuevana",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["es", "mx"],
        base_url: "https://ww1.cuevana3.is",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "homecine",
        label: "HomeCine",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["es", "mx"],
        base_url: "https://www3.homecine.to",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "verhdlink",
        label: "VerHdLink",
        content_types: &[MediaType::Movie],
        country_codes: &["es", "mx"],
        base_url: "https://verhdlink.cam",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "einschalten",
        label: "Einschalten",
        content_types: &[MediaType::Movie],
        country_codes: &["de"],
        base_url: "https://einschalten.in",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "kinoger",
        label: "KinoGer",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["de"],
        base_url: "https://kinoger.com",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "megakino",
        label: "MegaKino",
        content_types: &[MediaType::Movie],
        country_codes: &["de"],
        base_url: "https://megakino2.biz",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "meinecloud",
        label: "MeineCloud",
        content_types: &[MediaType::Movie],
        country_codes: &["de"],
        base_url: "https://meinecloud.click",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "filmpalast",
        label: "Filmpalast",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["de"],
        base_url: "https://filmpalast.to",
        priority: 1,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "streamkiste",
        label: "StreamKiste",
        content_types: &[MediaType::Series],
        country_codes: &["de"],
        base_url: "https://streamkiste.taxi",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "frembed",
        label: "Frembed",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["fr"],
        base_url: "https://frembed.cyou",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "frenchcloud",
        label: "FrenchCloud",
        content_types: &[MediaType::Movie],
        country_codes: &["fr"],
        base_url: "https://frenchcloud.cam",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "movix",
        label: "Movix",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["fr"],
        base_url: "https://api.movix.cash",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "eurostreaming",
        label: "Eurostreaming",
        content_types: &[MediaType::Series],
        country_codes: &["it"],
        base_url: "https://eurostreaming.luxe",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "mostraguarda",
        label: "MostraGuarda",
        content_types: &[MediaType::Movie],
        country_codes: &["it"],
        base_url: "https://mostraguarda.stream",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "vegamovies",
        label: "VegaMovies",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi", "hi", "en"],
        base_url: "https://vegamovies.market",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
];

pub fn source_by_id(id: &str) -> Option<&'static SourceDef> {
    ALL_SOURCES.iter().find(|s| s.id == id)
}

/// Builtin `SourceDef.base_url`, overridable via RFC-039 `webstreamr.{id}`.
pub fn resolved_base(source_id: &str) -> String {
    if let Some(u) = utils::provider_runtime::webstreamr_base(source_id) {
        return u;
    }
    source_by_id(source_id)
        .map(|d| d.base_url.to_string())
        .unwrap_or_default()
}

pub fn filter_embeds(embeds: Vec<SourceEmbed>, config: &Config, has_multi: bool) -> Vec<SourceEmbed> {
    if has_multi {
        return embeds;
    }
    embeds
        .into_iter()
        .filter(|e| e.country_codes.iter().any(|cc| config::country_enabled(config, cc)))
        .collect()
}

fn source_request_from(
    req: &SourceRequest,
    ids: &MediaIds,
) -> SourceRequest {
    SourceRequest {
        imdb_id: ids.imdb_id.clone().or_else(|| req.imdb_id.clone()),
        tmdb_id: ids.tmdb_id.or(req.tmdb_id),
        media_type: req.media_type,
        season: ids.season.or(req.season),
        episode: ids.episode.or(req.episode),
        title: req.title.clone(),
        year: req.year,
    }
}

fn fetch_cfg(referer: Option<&str>) -> FetchConfig {
    let mut headers = HashMap::new();
    if let Some(r) = referer {
        headers.insert("Referer".into(), r.into());
    }
    FetchConfig {
        headers,
        ..Default::default()
    }
}

fn parse_opts_json(value: serde_json::Value) -> String {
    value.to_string()
}

fn levenshtein(a: &str, b: &str) -> usize {
    let s = a.to_lowercase();
    let t = b.to_lowercase();
    if s == t {
        return 0;
    }
    if s.is_empty() {
        return t.len();
    }
    if t.is_empty() {
        return s.len();
    }
    let mut prev: Vec<usize> = (0..=t.len()).collect();
    let mut cur = vec![0; t.len() + 1];
    for (i, sc) in s.chars().enumerate() {
        cur[0] = i + 1;
        for (j, tc) in t.chars().enumerate() {
            let cost = if sc == tc { 0 } else { 1 };
            cur[j + 1] = (cur[j] + 1)
                .min(prev[j + 1] + 1)
                .min(prev[j] + cost);
        }
        std::mem::swap(&mut prev, &mut cur);
    }
    prev[t.len()]
}

pub fn run_source(
    source_id: &str,
    req: &SourceRequest,
    config: &Config,
    tmdb_token: Option<&str>,
) -> Vec<SourceEmbed> {
    let def = match source_by_id(source_id) {
        Some(d) => d,
        None => return Vec::new(),
    };
    if !def.content_types.contains(&req.media_type) {
        return Vec::new();
    }

    let ids = match resolve_ids(
        req.imdb_id.as_deref(),
        req.tmdb_id,
        req.media_type,
        req.season,
        req.episode,
        tmdb_token,
    ) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };
    let sr = source_request_from(req, &ids);

    let base = resolved_base(source_id);
    let embeds = match source_id {
        "vidsrc" | "vixsrc" | "rgshows" | "vidzee" => resolve_source(source_id, &sr),
        "moviebox" => super::moviebox::run(&ids, &sr, tmdb_token),
        "filmpalast" => super::filmpalast::run(&ids, &sr, tmdb_token),
        "meinecloud" => run_meinecloud(&ids, config),
        "verhdlink" | "frenchcloud" | "mostraguarda" => {
            run_imdb_movie_page(source_id, &ids, &base).unwrap_or_default()
        }
        "megakino" => run_megakino(&ids, &base).unwrap_or_default(),
        "homecine" => run_homecine(&sr, &ids, tmdb_token).unwrap_or_default(),
        "eurostreaming" => run_eurostreaming(&sr, &ids, tmdb_token).unwrap_or_default(),
        "cinehdplus" => run_cinehdplus(&ids).unwrap_or_default(),
        "streamkiste" => run_streamkiste(&ids).unwrap_or_default(),
        "einschalten" => run_einschalten(&ids).unwrap_or_default(),
        "movix" => run_movix(&sr, &ids, tmdb_token).unwrap_or_default(),
        "frembed" => run_frembed(&sr, &ids, tmdb_token).unwrap_or_default(),
        "kinoger" => run_kinoger(&sr, &ids, tmdb_token).unwrap_or_default(),
        "hdhub4u" => run_hdhub4u(&ids, tmdb_token).unwrap_or_default(),
        "vegamovies" => run_vegamovies(&ids).unwrap_or_default(),
        "4khdhub" => run_fourkhdhub(&sr, &ids, tmdb_token).unwrap_or_default(),
        "kokoshka" => run_kokoshka(&sr, &ids, tmdb_token).unwrap_or_default(),
        "cuevana" => run_cuevana(&sr, &ids, tmdb_token).unwrap_or_default(),
        _ => Vec::new(),
    };

    let has_multi = def.country_codes.contains(&"multi");
    filter_embeds(embeds, config, has_multi)
}

fn run_meinecloud(ids: &MediaIds, _config: &Config) -> Vec<SourceEmbed> {
    run_imdb_movie_page("meinecloud", ids, &resolved_base("meinecloud")).unwrap_or_default()
}

fn run_imdb_movie_page(source_id: &str, ids: &MediaIds, base_url: &str) -> Option<Vec<SourceEmbed>> {
    let imdb = ids.imdb_id.as_deref()?;
    let page_url = format!("{base_url}/movie/{imdb}");
    let html = fetch_text(&page_url, &fetch_cfg(Some(base_url))).ok()?;
    Some(parse_source_html(
        source_id,
        &html,
        &parse_opts_json(serde_json::json!({ "referer": base_url })),
    ))
}

fn run_megakino(ids: &MediaIds, base_url: &str) -> Option<Vec<SourceEmbed>> {
    let imdb = ids.imdb_id.as_deref()?;
    let base = final_redirect_url(base_url, &FetchConfig::default()).unwrap_or_else(|_| base_url.into());
    let origin = url_origin(&base);
    // MegaKino: HEAD ?yg=token so the cookie jar stores the
    // challenge cookie before search POST.
    let token_url = format!(
        "{}{}yg=token",
        base,
        if base.contains('?') { "&" } else { "?" }
    );
    let _ = fetch_head(&token_url, &FetchConfig::default());
    let form = format!(
        "do=search&subaction=search&story={}",
        urlencoding_encode(imdb)
    );
    let html = fetch_text_post(
        &base,
        &form,
        &FetchConfig {
            headers: HashMap::from([
                ("Content-Type".into(), "application/x-www-form-urlencoded".into()),
                ("Referer".into(), origin.clone()),
            ]),
            ..Default::default()
        },
    )
    .ok()?;
    let doc = Html::parse_document(&html);
    let href = doc
        .select(&Selector::parse("#dle-content a[href].poster").unwrap())
        .next()
        .and_then(|a| a.value().attr("href"))?;
    let page_url = resolve_href(&base, href);
    let page_html = fetch_text(&page_url, &fetch_cfg(Some(&page_url))).ok()?;
    Some(parse_source_html(
        "megakino",
        &page_html,
        &parse_opts_json(serde_json::json!({ "referer": page_url })),
    ))
}

fn url_origin(url: &str) -> String {
    url::Url::parse(url)
        .ok()
        .map(|u| format!("{}://{}", u.scheme(), u.host_str().unwrap_or("")))
        .unwrap_or_else(|| url.into())
}

fn urlencoding_encode(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}

fn resolve_href(base: &str, href: &str) -> String {
    if href.starts_with("http") {
        href.to_string()
    } else {
        url::Url::parse(base)
            .ok()
            .and_then(|b| b.join(href).ok())
            .map(|u| u.to_string())
            .unwrap_or_else(|| href.to_string())
    }
}

fn run_homecine(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, Some("es"), token).ok()?;
    let page_url = find_homecine_page(&ny.name, ids.season.is_some())
        .or_else(|| find_homecine_page(&ny.original_name, ids.season.is_some()))?;
    let mut html = fetch_text(&page_url, &FetchConfig::default()).ok()?;
    if ids.season.is_some() {
        if let Some(ep_url) = find_homecine_episode(&html, ids.season?, ids.episode?) {
            html = fetch_text(&ep_url, &FetchConfig::default()).ok()?;
        } else {
            return None;
        }
    }
    let title = if ids.season.is_some() {
        Some(series_title(
            &ny.name,
            ids.season.unwrap_or(1),
            ids.episode.unwrap_or(1),
        ))
    } else {
        req.title.clone().or(Some(format!("{} ({})", ny.name, ny.year)))
    };
    Some(parse_source_html(
        "homecine",
        &html,
        &parse_opts_json(serde_json::json!({
            "referer": page_url,
            "title": title,
        })),
    ))
}

fn find_homecine_page(name: &str, is_series: bool) -> Option<String> {
    let base = resolved_base("homecine");
    let search_url = format!("{base}/?s={}", urlencoding_encode(name));
    let html = fetch_text(&search_url, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&html);
    let keywords = [name.to_string(), name.replace('-', "–")];
    for k in &keywords {
        let sel = Selector::parse(&format!(r#"a[oldtitle="{k}"]"#)).ok()?;
        for a in doc.select(&sel) {
            let href = a.value().attr("href")?;
            let u = href.to_string();
            let series = u.contains("/series/");
            if is_series == series {
                return Some(resolve_href(&base, &u));
            }
        }
    }
    for a in doc.select(&Selector::parse("a[oldtitle]").unwrap()) {
        let ot = a.value().attr("oldtitle").unwrap_or("").trim();
        if levenshtein(ot, name) >= 5 {
            continue;
        }
        let href = a.value().attr("href")?;
        let u = href.to_string();
        let series = u.contains("/series/");
        if is_series == series {
            return Some(resolve_href(&base, &u));
        }
    }
    None
}

fn find_homecine_episode(html: &str, season: i32, episode: i32) -> Option<String> {
    let doc = Html::parse_document(html);
    let suffix = format!("-temporada-{season}-capitulo-{episode}");
    doc.select(&Selector::parse("#seasons a").unwrap())
        .find_map(|a| {
            let href = a.value().attr("href")?;
            href.ends_with(&suffix).then(|| href.to_string())
        })
}

fn run_eurostreaming(_req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, Some("it"), token).ok()?;
    let keyword = ny.name.replace([':', '-'], "");
    let base = resolved_base("eurostreaming");
    let post_url = format!("{base}/index.php?do=search");
    let origin = url_origin(&post_url);
    let body = format!("subaction=search&story={}", urlencoding_encode(&keyword));
    let html = fetch_text_post(
        &post_url,
        &body,
        &FetchConfig {
            headers: HashMap::from([
                ("Content-Type".into(), "application/x-www-form-urlencoded".into()),
                ("Referer".into(), origin),
            ]),
            ..Default::default()
        },
    )
    .ok()?;
    let series_url = find_eurostreaming_series(&html, &keyword)?;
    let page_html = fetch_text(&series_url, &FetchConfig::default()).ok()?;
    let title = format!(
        "{} S{:02}E{:02}",
        ny.name,
        ids.season.unwrap_or(1),
        ids.episode.unwrap_or(1)
    );
    Some(parse_source_html(
        "eurostreaming",
        &page_html,
        &parse_opts_json(serde_json::json!({
            "referer": series_url,
            "title": title,
            "season": ids.season,
            "episode": ids.episode,
        })),
    ))
}

fn find_eurostreaming_series(html: &str, keyword: &str) -> Option<String> {
    let doc = Html::parse_document(html);
    let mut exact = None;
    let mut similar = None;
    let mut partial = None;
    for a in doc.select(&Selector::parse(".post-thumb a[href]").unwrap()) {
        let href = a.value().attr("href")?;
        let title = a.value().attr("title").unwrap_or("").trim();
        if exact.is_none() && title == keyword {
            exact = Some(href.to_string());
        }
        if similar.is_none() && levenshtein(title, keyword) < 5 {
            similar = Some(href.to_string());
        }
        if partial.is_none() && title.contains(keyword) {
            partial = Some(href.to_string());
        }
    }
    exact.or(similar).or(partial)
}

fn run_cinehdplus(ids: &MediaIds) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let url = format!(
        "{}/series/?story={tmdb_id}&do=search&subaction=search",
        resolved_base("cinehdplus")
    );
    let html = fetch_text(&url, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&html);
    let href = doc
        .select(&Selector::parse(".card__title a[href]").unwrap())
        .next()
        .and_then(|a| a.value().attr("href"))?;
    let page_url = href.to_string();
    let page_html = fetch_text(&page_url, &FetchConfig::default()).ok()?;
    Some(parse_source_html(
        "cinehdplus",
        &page_html,
        &parse_opts_json(serde_json::json!({
            "referer": page_url,
            "season": ids.season,
            "episode": ids.episode,
        })),
    ))
}

fn run_streamkiste(ids: &MediaIds) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let url = format!(
        "{}/?story={tmdb_id}&do=search&subaction=search",
        resolved_base("streamkiste")
    );
    let html = fetch_text(&url, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&html);
    let href = doc
        .select(&Selector::parse(".res_item a[href]").unwrap())
        .next()
        .and_then(|a| a.value().attr("href"))?;
    let page_url = href.to_string();
    let page_html = fetch_text(&page_url, &FetchConfig::default()).ok()?;
    Some(parse_source_html(
        "streamkiste",
        &page_html,
        &parse_opts_json(serde_json::json!({
            "referer": page_url,
            "season": ids.season,
            "episode": ids.episode,
        })),
    ))
}

fn run_einschalten(ids: &MediaIds) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let api_url = format!(
        "{}/api/movies/{tmdb_id}/watch",
        resolved_base("einschalten")
    );
    let json = fetch_json(&api_url, &FetchConfig::default()).ok()?;
    Some(parse_source_html(
        "einschalten",
        &json.to_string(),
        &parse_opts_json(serde_json::json!({
            "referer": format!("{}/movies/{tmdb_id}", resolved_base("einschalten")),
        })),
    ))
}

fn run_movix(_req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, None, token).ok()?;
    let api_url = if ids.season.is_some() {
        format!(
            "{}/api/tmdb/tv/{tmdb_id}?season={}&episode={}",
            resolved_base("movix"),
            ids.season.unwrap_or(1),
            ids.episode.unwrap_or(1)
        )
    } else {
        format!("{}/api/tmdb/movie/{tmdb_id}", resolved_base("movix"))
    };
    let json = fetch_json(
        &api_url,
        &FetchConfig {
            headers: HashMap::from([("Accept".into(), "application/json".into())]),
            ..Default::default()
        },
    )
    .ok()?;
    let movix_base = resolved_base("movix");
    let referer = json
        .get(if ids.season.is_some() {
            "current_episode"
        } else {
            "iframe_src"
        })
        .and_then(|v| {
            if ids.season.is_some() {
                v.get("iframe_src").and_then(|x| x.as_str())
            } else {
                v.as_str()
            }
        })
        .unwrap_or(movix_base.as_str());
    Some(parse_source_html(
        "movix",
        &json.to_string(),
        &parse_opts_json(serde_json::json!({
            "referer": referer,
            "is_series": ids.season.is_some(),
            "season": ids.season,
            "episode": ids.episode,
            "year": ny.year,
        })),
    ))
}

fn run_frembed(_req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, None, token).ok()?;
    let base = final_redirect_url(&resolved_base("frembed"), &FetchConfig::default())
        .unwrap_or_else(|_| resolved_base("frembed"));
    let origin = url_origin(&base);
    let api_url = if ids.season.is_some() {
        format!(
            "{base}/api/series?id={tmdb_id}&sa={}&epi={}&idType=tmdb",
            ids.season.unwrap_or(1),
            ids.episode.unwrap_or(1)
        )
    } else {
        format!("{base}/api/films?id={tmdb_id}&idType=tmdb")
    };
    let json = fetch_json(
        &api_url,
        &fetch_cfg(Some(&origin)),
    )
    .ok()?;
    let rust = parse_source_html(
        "frembed",
        &json.to_string(),
        &parse_opts_json(serde_json::json!({
            "referer": origin,
            "is_series": ids.season.is_some(),
            "season": ids.season,
            "episode": ids.episode,
            "year": ny.year,
        })),
    );
    Some(rust.into_iter()
        .filter_map(|mut e| {
            let resolved = final_redirect_url(
                &e.url,
                &FetchConfig {
                    headers: HashMap::from([("Referer".into(), format!("{origin}/"))]),
                    ..Default::default()
                },
            )
            .ok()?;
            e.url = resolved;
            Some(e)
        })
        .collect())
}

fn run_kinoger(_req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, Some("de"), token).ok()?;
    let page_url = find_kinoger_page(&ny.name, ny.year)?;
    let html = fetch_text(&page_url, &FetchConfig::default()).ok()?;
    let season_index = ids.season.unwrap_or(1) - 1;
    let episode_index = ids.episode.unwrap_or(1) - 1;
    let urls = super::extract_kinoger_episode_urls(&html, season_index as usize, episode_index as usize);
    let title = if ids.season.is_some() {
        format!("{} {}x{}", ny.name, ids.season.unwrap_or(1), ids.episode.unwrap_or(1))
    } else {
        format!("{} ({})", ny.name, ny.year)
    };
    Some(urls.into_iter()
        .map(|url| SourceEmbed {
            url,
            title: Some(title.clone()),
            country_codes: vec!["de".into()],
            referer: Some(page_url.clone()),
            priority: None,
            height: None,
            bytes: None,
        })
        .collect())
}

fn find_kinoger_page(keyword: &str, year: i32) -> Option<String> {
    let base = resolved_base("kinoger");
    let search_url = format!(
        "{base}/?do=search&subaction=search&titleonly=3&story={}&x=0&y=0&submit=submit",
        urlencoding_encode(keyword)
    );
    let html = fetch_text(&search_url, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&html);
    let year_str = year.to_string();
    doc.select(&Selector::parse(".title a").unwrap())
        .find_map(|a| {
            let text: String = a.text().collect();
            if !text.contains(&year_str) {
                return None;
            }
            let href = a.value().attr("href")?;
            Some(resolve_href(&base, href))
        })
}

fn run_hdhub4u(ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let base = resolved_base("hdhub4u");
    let mut pages: Vec<(String, String)> = Vec::new(); // (url, post_title)

    if let Some(imdb) = ids.imdb_id.as_deref() {
        // Typesense may be dead (404) — ignore and fall through to HTML search.
        let search_url = format!(
            "https://search.hdhub4u.glass/collections/post/documents/search?query_by=imdb_id&q={}",
            urlencoding_encode(imdb)
        );
        if let Ok(resp) = fetch_json(&search_url, &fetch_cfg(Some(&base))) {
            if let Some(hits) = resp.get("hits").and_then(|v| v.as_array()) {
                for hit in hits {
                    let Some(doc) = hit.get("document") else { continue };
                    if doc.get("imdb_id").and_then(|v| v.as_str()) != Some(imdb) {
                        continue;
                    }
                    let post_title = doc
                        .get("post_title")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();
                    if let Some(season) = ids.season {
                        let s = season.to_string();
                        let s_pad = format!("{s:02}");
                        if !post_title.contains(&format!("Season {s}"))
                            && !post_title.contains(&format!("S{s}"))
                            && !post_title.contains(&format!("S{s_pad}"))
                        {
                            continue;
                        }
                    }
                    let Some(permalink) = doc.get("permalink").and_then(|v| v.as_str()) else {
                        continue;
                    };
                    pages.push((resolve_href(&base, permalink), post_title));
                }
            }
        }
    }

    if pages.is_empty() {
        let tmdb_id = ids.tmdb_id?;
        let ny = get_tmdb_name_and_year(tmdb_id, ids.season, None, token).ok()?;
        let q = if let Some(season) = ids.season {
            format!("{} Season {season}", ny.name)
        } else {
            ny.name.clone()
        };
        let search_url = format!(
            "{}/search/{}",
            base.trim_end_matches('/'),
            urlencoding_encode(&q)
        );
        let html = fetch_text(&search_url, &fetch_cfg(Some(&base))).ok()?;
        pages = parse_hdhub4u_search_html(&html, &base);
        if let Some(season) = ids.season {
            let s = season.to_string();
            let s_pad = format!("{s:02}");
            pages.retain(|(_, title)| {
                title.contains(&format!("Season {s}"))
                    || title.contains(&format!("S{s}"))
                    || title.contains(&format!("S{s_pad}"))
            });
        }
        // Prefer English / non-hindi when title search is fuzzy.
        if pages.len() > 1 {
            let eng: Vec<_> = pages
                .iter()
                .filter(|(_, t)| {
                    let low = t.to_lowercase();
                    low.contains("english") && !low.contains("hindi")
                })
                .cloned()
                .collect();
            if !eng.is_empty() {
                pages = eng;
            }
        }
    }

    if pages.is_empty() {
        return Some(vec![]);
    }

    let mut out = Vec::new();
    for (page_url, _) in pages {
        let Ok(html) = fetch_text(&page_url, &fetch_cfg(Some(&base))) else {
            continue;
        };
        let doc_html = Html::parse_document(&html);
        let mut lang_text = String::new();
        for div in doc_html.select(&Selector::parse("div").unwrap()) {
            let t: String = div.text().collect();
            if t.contains("Language") {
                lang_text = t;
                break;
            }
        }
        let mut ccs = vec!["multi".to_string()];
        ccs.extend(crate::language::find_country_codes(&lang_text));
        let opts = parse_opts_json(serde_json::json!({
            "referer": page_url,
            "country_codes": ccs,
        }));
        out.extend(parse_source_html("hdhub4u", &html, &opts));
        for a in doc_html.select(&Selector::parse(r#"a[href*="gadgetsweb"]"#).unwrap()) {
            let Some(href) = a.value().attr("href") else {
                continue;
            };
            let Ok(hub_links_url) = resolve_redirect_url(href, Some(&page_url)) else {
                continue;
            };
            let Ok(links_html) = fetch_text(&hub_links_url, &fetch_cfg(Some(&page_url))) else {
                continue;
            };
            out.extend(parse_source_html(
                "hdhub4u",
                &links_html,
                &parse_opts_json(serde_json::json!({
                    "referer": hub_links_url,
                    "country_codes": ccs,
                })),
            ));
        }
    }
    Some(out)
}

fn parse_hdhub4u_search_html(html: &str, base: &str) -> Vec<(String, String)> {
    let doc = Html::parse_document(html);
    let Ok(sel) = Selector::parse("a[href]") else {
        return Vec::new();
    };
    let base_host = url::Url::parse(base)
        .ok()
        .and_then(|u| u.host_str().map(|h| h.to_string()));
    let mut best: HashMap<String, String> = HashMap::new();
    for a in doc.select(&sel) {
        let Some(href) = a.value().attr("href") else {
            continue;
        };
        let abs = resolve_href(base, href);
        let Ok(u) = url::Url::parse(&abs) else {
            continue;
        };
        if let Some(ref bh) = base_host {
            if u.host_str() != Some(bh.as_str()) {
                continue;
            }
        }
        let parts: Vec<_> = u
            .path()
            .split('/')
            .filter(|p| !p.is_empty())
            .collect();
        if parts.len() != 1 || parts[0].len() <= 5 || !parts[0].contains('-') {
            continue;
        }
        let title_attr = a.value().attr("title").unwrap_or("").trim();
        let text: String = a.text().collect::<String>();
        let text = text.split_whitespace().collect::<Vec<_>>().join(" ");
        let title = if title_attr.len() >= text.len() {
            title_attr.to_string()
        } else {
            text
        };
        let entry = best.entry(abs).or_default();
        if title.len() > entry.len() {
            *entry = title;
        }
    }
    best.into_iter().map(|(url, title)| (url, title)).collect()
}

fn run_vegamovies(ids: &MediaIds) -> Option<Vec<SourceEmbed>> {
    let imdb = ids.imdb_id.as_deref()?;
    let search_url = format!(
        "{}/search.php?q={}&page=1",
        resolved_base("vegamovies"),
        urlencoding_encode(imdb)
    );
    let resp = fetch_json(&search_url, &fetch_cfg(Some(&resolved_base("vegamovies")))).ok()?;
    let hits = resp.get("hits").and_then(|v| v.as_array()).cloned().unwrap_or_default();
    let mut out = Vec::new();
    for hit in hits {
        let doc = match hit.get("document") {
            Some(d) => d,
            None => continue,
        };
        if doc.get("imdb_id").and_then(|v| v.as_str()) != Some(imdb) {
            continue;
        }
        let post_title = doc.get("post_title").and_then(|v| v.as_str()).unwrap_or("");
        let lower = post_title.to_lowercase();
        if lower.contains("trailer") || lower.contains("coming soon") {
            continue;
        }
        if let Some(season) = ids.season {
            if !season_matches(post_title, season) {
                continue;
            }
        } else if post_title.contains("Season ") || VEGAMOVIES_SEASON_RE.is_match(post_title) {
            continue;
        }
        let permalink = doc.get("permalink").and_then(|v| v.as_str())?;
        let page_url = resolve_href(&resolved_base("vegamovies"), permalink);
        let html = fetch_text(&page_url, &fetch_cfg(Some(&resolved_base("vegamovies")))).ok()?;
        out.extend(parse_source_html(
            "vegamovies",
            &html,
            &parse_opts_json(serde_json::json!({
                "referer": page_url,
                "episode": ids.episode,
            })),
        ));
    }
    Some(out)
}

fn season_matches(text: &str, season: i32) -> bool {
    let s = season.to_string();
    if Regex::new(&format!(r"(?i)\bSeason\s*0*{s}\b"))
        .unwrap()
        .is_match(text)
    {
        return true;
    }
    if Regex::new(&format!(r"(?i)\bS0?{s}\b"))
        .unwrap()
        .is_match(text)
    {
        return true;
    }
    false
}

fn run_fourkhdhub(_req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, None, token).ok()?;
    let base = final_redirect_url(&resolved_base("4khdhub"), &FetchConfig::default())
        .unwrap_or_else(|_| resolved_base("4khdhub"));
    let search_url = format!("{base}/?s={}", urlencoding_encode(&ny.name));
    let html = fetch_text(&search_url, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&html);
    let href = doc
        .select(&Selector::parse("article h2 a").unwrap())
        .find_map(|a| {
            let t: String = a.text().collect();
            if levenshtein(&t, &ny.name) >= 4 {
                return None;
            }
            a.value().attr("href").map(|h| h.to_string())
        })?;
    let page_url = resolve_href(&base, &href);
    let page_html = fetch_text(&page_url, &FetchConfig::default()).ok()?;
    Some(parse_source_html(
        "4khdhub",
        &page_html,
        &parse_opts_json(serde_json::json!({
            "referer": page_url,
            "is_series": ids.season.is_some(),
            "season": ids.season,
            "episode": ids.episode,
        })),
    ))
}

fn run_kokoshka(_req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let page_url = find_kokoshka_page(tmdb_id, ids.season, token, "sq")
        .or_else(|| find_kokoshka_page(tmdb_id, ids.season, token, "en"))?;
    let mut current = page_url.clone();
    if ids.season.is_some() {
        let html = fetch_text(&current, &FetchConfig::default()).ok()?;
        current = find_kokoshka_episode(&html, ids.season?, ids.episode?)?;
    }
    let page_html = fetch_text(&current, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&page_html);
    let title = doc
        .select(&Selector::parse("title").unwrap())
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .unwrap_or_default();
    let apis = parse_source_html(
        "kokoshka",
        &page_html,
        &parse_opts_json(serde_json::json!({
            "referer": current,
            "base_url": resolved_base("kokoshka"),
        })),
    );
    let mut out = Vec::new();
    for api in apis {
        let Ok(json) = fetch_json(&api.url, &fetch_cfg(Some(&current))) else {
            continue;
        };
        out.extend(parse_source_html(
            "kokoshka",
            &json.to_string(),
            &parse_opts_json(serde_json::json!({
                "referer": current,
                "title": title,
                "body_kind": "dooplayer",
            })),
        ));
    }
    Some(out)
}

fn find_kokoshka_page(
    tmdb_id: i64,
    season: Option<i32>,
    token: Option<&str>,
    language: &str,
) -> Option<String> {
    let ny = get_tmdb_name_and_year(tmdb_id, season, Some(language), token).ok()?;
    let query = format!("{} {}", ny.name.replace(':', ""), ny.year);
    let base = resolved_base("kokoshka");
    let search_url = format!("{base}/?s={}", urlencoding_encode(&query));
    let html = fetch_text(&search_url, &FetchConfig::default()).ok()?;
    let doc = Html::parse_document(&html);
    let is_series = season.is_some();
    for item in doc.select(&Selector::parse(".result-item").unwrap()) {
        let kind_sel = if is_series { ".tvshows" } else { ".movies" };
        if item.select(&Selector::parse(kind_sel).unwrap()).next().is_none() {
            continue;
        }
        let y_text = item
            .select(&Selector::parse(".year").unwrap())
            .next()
            .map(|el| el.text().collect::<String>())
            .unwrap_or_default();
        let ry: i32 = y_text.chars().filter(|c| c.is_ascii_digit()).collect::<String>().parse().unwrap_or(0);
        if (ry - ny.year).abs() > 1 {
            continue;
        }
        let t_text = item
            .select(&Selector::parse(".title").unwrap())
            .next()
            .map(|el| el.text().collect::<String>())
            .unwrap_or_default();
        let cleaned = KOKOSHKA_TITLE_RE
            .replace(&t_text, "")
            .trim()
            .to_string();
        if levenshtein(&cleaned, &ny.name) >= 3 {
            continue;
        }
        let href = item
            .select(&Selector::parse("a").unwrap())
            .next()
            .and_then(|a| a.value().attr("href"))?;
        return Some(resolve_href(&base, href));
    }
    None
}

fn find_kokoshka_episode(html: &str, season: i32, episode: i32) -> Option<String> {
    let doc = Html::parse_document(html);
    let marker = format!("{season}x{episode}");
    let sel = Selector::parse(&format!(r#".episodiotitle a[href*="{marker}"]"#)).ok()?;
    let href = doc.select(&sel).next()?.value().attr("href")?;
    Some(resolve_href(&resolved_base("kokoshka"), href))
}

fn run_cuevana(_req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, Some("es"), token).ok()?;
    let mut page_url = find_cuevana_page(&ny.name)?;
    let title = if ids.season.is_some() {
        page_url = find_cuevana_episode(&page_url, ids.season?, ids.episode?)?;
        series_title(&ny.name, ids.season.unwrap_or(1), ids.episode.unwrap_or(1))
    } else {
        format!("{} ({})", ny.name, ny.year)
    };
    let html = fetch_text(&page_url, &FetchConfig::default()).ok()?;
    let mut out = parse_source_html(
        "cuevana",
        &html,
        &parse_opts_json(serde_json::json!({
            "referer": page_url,
            "title": title,
        })),
    );
    let origin = url_origin(&page_url);
    out = out
        .into_iter()
        .filter_map(|mut e| {
            if !e.url.contains("cuevana3") {
                return Some(e);
            }
            let h = fetch_text(
                &e.url,
                &fetch_cfg(Some(&origin)),
            )
            .ok()?;
            let re = Regex::new(r"url ?= ?'(.*)'").unwrap();
            let cap = re.captures(&h)?;
            e.url = cap.get(1)?.as_str().to_string();
            Some(e)
        })
        .collect();
    Some(out)
}

fn find_cuevana_page(keyword: &str) -> Option<String> {
    let base = resolved_base("cuevana");
    let search_url = format!("{base}/search/{}/", urlencoding_encode(keyword));
    let origin = url_origin(&search_url);
    let html = fetch_text(&search_url, &fetch_cfg(Some(&origin))).ok()?;
    let doc = Html::parse_document(&html);
    for t in doc.select(&Selector::parse(".TPost .Title").unwrap()) {
        if t.text().collect::<String>().trim() != keyword {
            continue;
        }
        let mut p = t.parent().and_then(ElementRef::wrap);
        while let Some(el) = p {
            if el.value().name() == "a" {
                let href = el.value().attr("href")?;
                return Some(if href.starts_with("http") {
                    href.to_string()
                } else {
                    format!("{origin}{href}")
                });
            }
            p = el.parent().and_then(ElementRef::wrap);
        }
    }
    None
}

fn find_cuevana_episode(page_url: &str, season: i32, episode: i32) -> Option<String> {
    let origin = url_origin(page_url);
    let html = fetch_text(page_url, &fetch_cfg(Some(&origin))).ok()?;
    let doc = Html::parse_document(&html);
    let marker = format!("{season}x{episode}");
    for y in doc.select(&Selector::parse(".TPost .Year").unwrap()) {
        if y.text().collect::<String>().trim() != marker {
            continue;
        }
        let mut p = y.parent().and_then(ElementRef::wrap);
        while let Some(el) = p {
            if el.value().name() == "a" {
                let href = el.value().attr("href")?;
                return Some(if href.starts_with("http") {
                    href.to_string()
                } else {
                    format!("{origin}{href}")
                });
            }
            p = el.parent().and_then(ElementRef::wrap);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn source_registry_has_vidsrc() {
        assert!(source_by_id("vidsrc").is_some());
        assert_eq!(ALL_SOURCES.len(), 24);
    }

    #[test]
    fn vidsrc_resolve_without_network() {
        let req = SourceRequest {
            imdb_id: Some("tt0944947".into()),
            tmdb_id: Some(1399),
            media_type: MediaType::Series,
            season: Some(1),
            episode: Some(1),
            title: Some("Game of Thrones".into()),
            year: Some(2011),
        };
        let embeds = resolve_source("vidsrc", &req);
        assert_eq!(embeds.len(), 1);
        assert!(embeds[0].url.contains("vidsrcme.ru"));
        assert!(embeds[0].url.contains("tt0944947"));
    }
}
