use super::{
    parse_source_html, resolve_source, series_title, SourceEmbed, SourceRequest,
};
use crate::config::{self, Config};
use crate::fetcher::{fetch_json, fetch_text, fetch_text_post, final_redirect_url, FetchConfig};
use crate::tmdb::{get_tmdb_name_and_year, resolve_ids, MediaIds};
use crate::types::MediaType;
use regex::Regex;
use scraper::{ElementRef, Html, Selector};
use std::collections::HashMap;

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

pub const ALL_SOURCES: &[SourceDef] = &[
    SourceDef {
        id: "vidsrc",
        label: "VidSrc",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi"],
        base_url: "https://vidsrc-embed.ru",
        priority: 0,
        use_only_with_max_urls_found: Some(0),
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
        id: "rgshows",
        label: "RGShows",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi"],
        base_url: "https://rgshows.ru",
        priority: -1,
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
        id: "verhdlink",
        label: "VerHdLink",
        content_types: &[MediaType::Movie],
        country_codes: &["es", "mx"],
        base_url: "https://verhdlink.cam",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "megakino",
        label: "MegaKino",
        content_types: &[MediaType::Movie],
        country_codes: &["de"],
        base_url: "https://megakino1.to",
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
        id: "mostraguarda",
        label: "MostraGuarda",
        content_types: &[MediaType::Movie],
        country_codes: &["it"],
        base_url: "https://mostraguarda.stream",
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
        id: "cinehdplus",
        label: "CineHDPlus",
        content_types: &[MediaType::Series],
        country_codes: &["es", "mx"],
        base_url: "https://cinehdplus.gratis",
        priority: 0,
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
        id: "frenchcloud",
        label: "FrenchCloud",
        content_types: &[MediaType::Movie],
        country_codes: &["fr"],
        base_url: "https://frenchcloud.cam",
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
        id: "hdhub4u",
        label: "HDHub4u",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi", "gu", "hi", "ml", "pa", "ta", "te"],
        base_url: "https://new5.hdhub4u.fo",
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
        id: "movix",
        label: "Movix",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["fr"],
        base_url: "https://api.movix.site",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
    SourceDef {
        id: "frembed",
        label: "Frembed",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["fr"],
        base_url: "https://frembed.work",
        priority: 0,
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
        id: "4khdhub",
        label: "4KHDHub",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["multi", "hi", "ta", "te"],
        base_url: "https://4khdhub.dad",
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
    SourceDef {
        id: "kinoger",
        label: "KinoGer",
        content_types: &[MediaType::Movie, MediaType::Series],
        country_codes: &["de"],
        base_url: "https://kinoger.com",
        priority: 0,
        use_only_with_max_urls_found: None,
    },
];

pub fn source_by_id(id: &str) -> Option<&'static SourceDef> {
    ALL_SOURCES.iter().find(|s| s.id == id)
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

    let embeds = match source_id {
        "vidsrc" | "vixsrc" | "rgshows" => resolve_source(source_id, &sr),
        "meinecloud" => run_meinecloud(&ids, config),
        "verhdlink" | "frenchcloud" | "mostraguarda" => {
            run_imdb_movie_page(source_id, &ids, def.base_url).unwrap_or_default()
        }
        "megakino" => run_megakino(&ids, def.base_url).unwrap_or_default(),
        "homecine" => run_homecine(&sr, &ids, tmdb_token).unwrap_or_default(),
        "eurostreaming" => run_eurostreaming(&sr, &ids, tmdb_token).unwrap_or_default(),
        "cinehdplus" => run_cinehdplus(&ids).unwrap_or_default(),
        "streamkiste" => run_streamkiste(&ids).unwrap_or_default(),
        "einschalten" => run_einschalten(&ids).unwrap_or_default(),
        "movix" => run_movix(&sr, &ids, tmdb_token).unwrap_or_default(),
        "frembed" => run_frembed(&sr, &ids, tmdb_token).unwrap_or_default(),
        "kinoger" => run_kinoger(&sr, &ids, tmdb_token).unwrap_or_default(),
        "hdhub4u" => run_hdhub4u(&ids).unwrap_or_default(),
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
    run_imdb_movie_page("meinecloud", ids, "https://meinecloud.click").unwrap_or_default()
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
    let origin = UrlOrigin::from(&base);
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

struct UrlOrigin(String);
impl UrlOrigin {
    fn from(url: &str) -> String {
        url::Url::parse(url)
            .ok()
            .map(|u| format!("{}://{}", u.scheme(), u.host_str().unwrap_or("")))
            .unwrap_or_else(|| url.into())
    }
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
    let base = "https://www3.homecine.to";
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
                return Some(resolve_href(base, &u));
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
            return Some(resolve_href(base, &u));
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

fn run_eurostreaming(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, Some("it"), token).ok()?;
    let keyword = ny.name.replace(':', "").replace('-', "");
    let base = "https://eurostreaming.luxe";
    let post_url = format!("{base}/index.php?do=search");
    let origin = UrlOrigin::from(&post_url);
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
        "https://cinehdplus.gratis/series/?story={tmdb_id}&do=search&subaction=search"
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
        "https://streamkiste.taxi/?story={tmdb_id}&do=search&subaction=search"
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
    let api_url = format!("https://einschalten.in/api/movies/{tmdb_id}/watch");
    let json = fetch_json(&api_url, &FetchConfig::default()).ok()?;
    Some(parse_source_html(
        "einschalten",
        &json.to_string(),
        &parse_opts_json(serde_json::json!({
            "referer": format!("https://einschalten.in/movies/{tmdb_id}"),
        })),
    ))
}

fn run_movix(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, None, token).ok()?;
    let api_url = if ids.season.is_some() {
        format!(
            "https://api.movix.site/api/tmdb/tv/{tmdb_id}?season={}&episode={}",
            ids.season.unwrap_or(1),
            ids.episode.unwrap_or(1)
        )
    } else {
        format!("https://api.movix.site/api/tmdb/movie/{tmdb_id}")
    };
    let json = fetch_json(
        &api_url,
        &FetchConfig {
            headers: HashMap::from([("Accept".into(), "application/json".into())]),
            ..Default::default()
        },
    )
    .ok()?;
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
        .unwrap_or("https://api.movix.site");
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

fn run_frembed(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, None, token).ok()?;
    let base = final_redirect_url("https://frembed.work", &FetchConfig::default())
        .unwrap_or_else(|_| "https://frembed.work".into());
    let origin = UrlOrigin::from(&base);
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

fn run_kinoger(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
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
    let base = "https://kinoger.com";
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
            Some(resolve_href(base, href))
        })
}

fn run_hdhub4u(ids: &MediaIds) -> Option<Vec<SourceEmbed>> {
    let imdb = ids.imdb_id.as_deref()?;
    let search_url = format!(
        "https://search.pingora.fyi/collections/post/documents/search?query_by=imdb_id&q={}",
        urlencoding_encode(imdb)
    );
    let resp = fetch_json(
        &search_url,
        &fetch_cfg(Some("https://new5.hdhub4u.fo")),
    )
    .ok()?;
    let hits = resp.get("hits").and_then(|v| v.as_array())?;
    let mut out = Vec::new();
    for hit in hits {
        let doc = hit.get("document")?;
        if doc.get("imdb_id").and_then(|v| v.as_str()) != Some(imdb) {
            continue;
        }
        let post_title = doc.get("post_title").and_then(|v| v.as_str()).unwrap_or("");
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
        let permalink = doc.get("permalink").and_then(|v| v.as_str())?;
        let page_url = resolve_href("https://new5.hdhub4u.fo", permalink);
        let html = fetch_text(&page_url, &fetch_cfg(Some("https://new5.hdhub4u.fo"))).ok()?;
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
        out.extend(parse_source_html(
            "hdhub4u",
            &html,
            &parse_opts_json(serde_json::json!({
                "referer": page_url,
                "country_codes": ccs,
            })),
        ));
    }
    Some(out)
}

fn run_vegamovies(ids: &MediaIds) -> Option<Vec<SourceEmbed>> {
    let imdb = ids.imdb_id.as_deref()?;
    let search_url = format!(
        "https://vegamovies.market/search.php?q={}&page=1",
        urlencoding_encode(imdb)
    );
    let resp = fetch_json(&search_url, &fetch_cfg(Some("https://vegamovies.market"))).ok()?;
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
        } else if post_title.contains("Season ") || Regex::new(r"\bS\d{1,2}\b").unwrap().is_match(post_title) {
            continue;
        }
        let permalink = doc.get("permalink").and_then(|v| v.as_str())?;
        let page_url = resolve_href("https://vegamovies.market", permalink);
        let html = fetch_text(&page_url, &fetch_cfg(Some("https://vegamovies.market"))).ok()?;
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

fn run_fourkhdhub(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, None, token).ok()?;
    let base = final_redirect_url("https://4khdhub.dad", &FetchConfig::default())
        .unwrap_or_else(|_| "https://4khdhub.dad".into());
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

fn run_kokoshka(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
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
            "base_url": "https://kokoshka.digital",
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
    let base = "https://kokoshka.digital";
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
        let cleaned = Regex::new(r"\(\d+\).*")
            .unwrap()
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
        return Some(resolve_href(base, href));
    }
    None
}

fn find_kokoshka_episode(html: &str, season: i32, episode: i32) -> Option<String> {
    let doc = Html::parse_document(html);
    let marker = format!("{season}x{episode}");
    let sel = Selector::parse(&format!(r#".episodiotitle a[href*="{marker}"]"#)).ok()?;
    let href = doc.select(&sel).next()?.value().attr("href")?;
    Some(resolve_href("https://kokoshka.digital", href))
}

fn run_cuevana(req: &SourceRequest, ids: &MediaIds, token: Option<&str>) -> Option<Vec<SourceEmbed>> {
    let tmdb_id = ids.tmdb_id?;
    let ny = get_tmdb_name_and_year(tmdb_id, ids.season, Some("es"), token).ok()?;
    let mut page_url = find_cuevana_page(&ny.name)?;
    let mut title = ny.name.clone();
    if ids.season.is_some() {
        title = series_title(&ny.name, ids.season.unwrap_or(1), ids.episode.unwrap_or(1));
        page_url = find_cuevana_episode(&page_url, ids.season?, ids.episode?)?;
    } else {
        title = format!("{} ({})", ny.name, ny.year);
    }
    let html = fetch_text(&page_url, &FetchConfig::default()).ok()?;
    let mut out = parse_source_html(
        "cuevana",
        &html,
        &parse_opts_json(serde_json::json!({
            "referer": page_url,
            "title": title,
        })),
    );
    let origin = UrlOrigin::from(&page_url);
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
    let base = "https://ww1.cuevana3.is";
    let search_url = format!("{base}/search/{}/", urlencoding_encode(keyword));
    let origin = UrlOrigin::from(&search_url);
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
    let origin = UrlOrigin::from(page_url);
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
        assert_eq!(ALL_SOURCES.len(), 21);
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
        assert!(embeds[0].url.contains("vidsrc"));
    }
}
