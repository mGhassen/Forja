use forja_webstreamr::parse_source_html;
use forja_webstreamr::resolve_source;
use forja_webstreamr::types::MediaType;
use forja_webstreamr::SourceRequest;

#[test]
fn vidsrc_movie_tmdb_golden() {
    let req = SourceRequest {
        tmdb_id: Some(550),
        imdb_id: None,
        media_type: MediaType::Movie,
        season: None,
        episode: None,
        title: None,
        year: None,
    };
    let rows = resolve_source("vidsrc", &req);
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].url, "https://vidsrc-embed.ru/embed/movie/550");
    assert_eq!(rows[0].country_codes, vec!["multi"]);
}

#[test]
fn vidsrc_series_imdb_golden() {
    let req = SourceRequest {
        tmdb_id: None,
        imdb_id: Some("tt0944947".into()),
        media_type: MediaType::Series,
        season: Some(1),
        episode: Some(1),
        title: None,
        year: None,
    };
    let rows = resolve_source("vidsrc", &req);
    assert_eq!(rows[0].url, "https://vidsrc-embed.ru/embed/tv/tt0944947/1-1");
}

#[test]
fn vixsrc_movie_golden() {
    let req = SourceRequest {
        tmdb_id: Some(550),
        imdb_id: None,
        media_type: MediaType::Movie,
        season: None,
        episode: None,
        title: Some("Fight Club".into()),
        year: Some(1999),
    };
    let rows = resolve_source("vixsrc", &req);
    assert_eq!(rows[0].url, "https://vixsrc.to/movie/550");
    assert_eq!(rows[0].title.as_deref(), Some("Fight Club (1999)"));
    assert_eq!(rows[0].priority, Some(1));
}

#[test]
fn rgshows_series_golden() {
    let req = SourceRequest {
        tmdb_id: Some(1399),
        imdb_id: None,
        media_type: MediaType::Series,
        season: Some(2),
        episode: Some(5),
        title: Some("Game of Thrones".into()),
        year: Some(2011),
    };
    let rows = resolve_source("rgshows", &req);
    assert_eq!(rows[0].url, "https://api.rgshows.ru/main/tv/1399/2/5");
    assert_eq!(rows[0].title.as_deref(), Some("Game of Thrones S02E05"));
    assert_eq!(rows[0].priority, Some(-1));
}

#[test]
fn meinecloud_html_golden() {
    let html = r#"<div data-link="//embed.example/a"></div>"#;
    let rows = parse_source_html("meinecloud", html, r#"{"referer":"https://meinecloud.click"}"#);
    assert_eq!(rows[0].url, "https://embed.example/a");
    assert_eq!(rows[0].country_codes, vec!["de"]);
}

#[test]
fn verhdlink_html_golden() {
    let html = r#"<div class="_player-mirrors latino"><a data-link="https://cdn.example/lat"></a></div>"#;
    let rows = parse_source_html("verhdlink", html, r#"{"referer":"https://verhdlink.cam"}"#);
    assert_eq!(rows[0].country_codes, vec!["mx"]);
}

#[test]
fn megakino_html_golden() {
    let html = r#"<meta property="og:title" content="Film"><div class="video-inside"><iframe src="https://embed.example/x"></iframe></div>"#;
    let rows = parse_source_html("megakino", html, r#"{"referer":"https://megakino.example/p"}"#);
    assert_eq!(rows[0].url, "https://embed.example/x");
    assert_eq!(rows[0].title.as_deref(), Some("Film"));
}

#[test]
fn homecine_html_golden() {
    let html = r#"<div class="les-content"><a>Latino<iframe src="https://embed.example/lat"></iframe></a></div>"#;
    let rows = parse_source_html(
        "homecine",
        html,
        r#"{"referer":"https://homecine.example/p","title":"Film (2020)"}"#,
    );
    assert_eq!(rows[0].url, "https://embed.example/lat");
    assert_eq!(rows[0].country_codes, vec!["mx"]);
    assert_eq!(rows[0].title.as_deref(), Some("Film (2020)"));
}
