use std::collections::HashMap;
use std::sync::LazyLock;

use regex::Regex;
use scraper::{ElementRef, Html, Selector};
use serde::Serialize;
use serde_json::Value;

use crate::http::BASE_URL;

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct AutocompleteHit {
    pub id: i64,
    pub slug: String,
    pub label: String,
    pub title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year: Option<i32>,
    pub is_tv: bool,
    pub url: String,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct SimilarItem {
    pub id: i64,
    pub slug: String,
    pub title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rating: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vote_count: Option<String>,
    pub thumb_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub similarity_percent: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub genre: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub country: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub story: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub style_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub plot_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub audience_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub time_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub place_tags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct Details {
    pub id: i64,
    pub slug: String,
    pub title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rating: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vote_count: Option<String>,
    pub thumb_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub story: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub genre: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub country: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub style_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub plot_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub audience_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub time_tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub place_tags: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub blurb: Option<String>,
    #[serde(default)]
    pub similar: Vec<SimilarItem>,
}

static RE_YEAR_SUFFIX: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\((\d{4})\)\s*$").unwrap());
static RE_TITLE_YEAR: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\((\d{4})\)").unwrap());
static RE_H1_TITLE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)^Movies?\s+(?:Like|Similar to)\s+(.+)$").unwrap());
static RE_TEXT_NUMBER: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(\d+(?:\.\d+)?)").unwrap());
static RE_VOTE_CLEAN: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[^A-Z0-9.,]").unwrap());

fn text_of(el: ElementRef<'_>) -> String {
    el.text().collect::<String>().trim().to_string()
}

fn is_descendant_of(node: ElementRef<'_>, ancestor: ElementRef<'_>) -> bool {
    let mut current = node.parent();
    while let Some(parent) = current {
        if parent.id() == ancestor.id() {
            return true;
        }
        current = parent.parent();
    }
    false
}

fn text_number(s: &str) -> String {
    RE_TEXT_NUMBER
        .captures(s)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string())
        .unwrap_or_default()
}

fn clean_vote_count(raw: &str) -> Option<String> {
    let cleaned = RE_VOTE_CLEAN.replace_all(raw.trim(), "").to_string();
    if cleaned.is_empty() {
        None
    } else {
        Some(cleaned)
    }
}

fn parse_tags(value_text: &str) -> Vec<String> {
    value_text
        .split(',')
        .map(str::trim)
        .filter(|t| !t.is_empty() && *t != "...")
        .map(str::to_string)
        .collect()
}

fn collect_attrs(
    el: ElementRef<'_>,
    attrs: &mut HashMap<String, String>,
    tags: &mut HashMap<String, Vec<String>>,
    entry_sel: &Selector,
    value_sel: &Selector,
) {
    let entry = el
        .select(entry_sel)
        .next()
        .map(text_of)
        .unwrap_or_default();
    let Some(value_el) = el.select(value_sel).next() else {
        return;
    };
    if entry.is_empty() {
        return;
    }
    let key = entry.trim_end_matches(':').trim().to_lowercase();
    if el.value().classes().any(|c| c == "attr-tag") {
        tags.insert(key, parse_tags(&text_of(value_el)));
    } else {
        attrs.insert(key, text_of(value_el));
    }
}

fn absolute_url(src: &str) -> String {
    if src.starts_with("http") {
        src.to_string()
    } else {
        format!("{BASE_URL}{src}")
    }
}

fn id_from_value(v: &Value) -> Option<i64> {
    v.as_i64().or_else(|| v.as_str().and_then(|s| s.parse().ok()))
}

/// Parse autocomplete JSON from bestsimilar.com `/site/autocomplete`.
pub fn parse_autocomplete_json(body: &str) -> Vec<AutocompleteHit> {
    let Ok(data) = serde_json::from_str::<Value>(body) else {
        return Vec::new();
    };
    let Some(movies) = data.get("movie").and_then(Value::as_array) else {
        return Vec::new();
    };

    let mut out = Vec::new();
    for m in movies {
        let Some(obj) = m.as_object() else {
            continue;
        };
        let Some(id) = obj.get("id").and_then(id_from_value) else {
            continue;
        };

        let url = obj.get("url").and_then(Value::as_str).unwrap_or("").trim();
        let label = obj.get("label").and_then(Value::as_str).unwrap_or("").trim();
        if url.is_empty() || label.is_empty() {
            continue;
        }

        let serial = obj
            .get("serial")
            .map(|v| v.as_str().unwrap_or("").to_string())
            .unwrap_or_default();
        let is_tv = serial == "1";

        let year = RE_YEAR_SUFFIX
            .captures(label)
            .and_then(|c| c.get(1))
            .and_then(|m| m.as_str().parse().ok());
        let title = RE_YEAR_SUFFIX.replace(label, "").trim().to_string();
        let slug = url.trim_start_matches("/movies/").to_string();

        out.push(AutocompleteHit {
            id,
            slug,
            label: label.to_string(),
            title,
            year,
            is_tv,
            url: url.to_string(),
        });
    }
    out
}

/// Score and pick the best autocomplete hit for a TMDB-style (title, year, is_tv) tuple.
pub fn find_best_hit<'a>(
    hits: &'a [AutocompleteHit],
    title: &str,
    year: Option<i32>,
    is_tv: bool,
) -> Option<&'a AutocompleteHit> {
    if hits.is_empty() {
        return None;
    }
    let title_lower = title.to_lowercase();
    let mut best: Option<&AutocompleteHit> = None;
    let mut best_score = -1.0_f64;

    for h in hits {
        let mut score = 0.0;
        let h_title_lower = h.title.to_lowercase();
        if h_title_lower == title_lower {
            score += 5.0;
        }
        if h_title_lower.starts_with(&title_lower) {
            score += 1.0;
        }
        if let Some(want_year) = year {
            if h.year == Some(want_year) {
                score += 4.0;
            }
            if let Some(hy) = h.year {
                if (hy - want_year).abs() <= 1 {
                    score += 1.0;
                }
            }
        }
        if h.is_tv == is_tv {
            score += 1.5;
        }
        if score > best_score {
            best_score = score;
            best = Some(h);
        }
    }

    if best_score >= 4.0 {
        best
    } else {
        None
    }
}

/// Parse a movie detail page HTML (hero + similar items).
pub fn parse_details_html(id: i64, slug: &str, html: &str) -> Option<Details> {
    let doc = Html::parse_document(html);
    let h1_sel = Selector::parse("h1").ok()?;
    let title_sel = Selector::parse("title").ok()?;
    let h_desc_sel = Selector::parse(".h-desc").ok()?;
    let rel_root_sel = Selector::parse("#movie-rel-list").ok()?;
    let attr_sel = Selector::parse(".attr").ok()?;
    let entry_sel = Selector::parse(".entry").ok()?;
    let value_sel = Selector::parse(".value").ok()?;
    let img_sel = Selector::parse("img").ok()?;
    let rat_rating_sel = Selector::parse(".rat-rating").ok()?;
    let rat_vote_sel = Selector::parse(".rat-vote").ok()?;
    let item_sel = Selector::parse(".item.item-movie").ok()?;
    let name_sel = Selector::parse("a.name").ok()?;
    let smt_sel = Selector::parse(".smt-value").ok()?;

    let mut title = String::new();
    let mut year: Option<i32> = None;

    if let Some(h1) = doc.select(&h1_sel).next() {
        let raw = text_of(h1);
        title = RE_H1_TITLE
            .captures(&raw)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().trim().to_string())
            .unwrap_or(raw);
    }

    if let Some(page_title) = doc.select(&title_sel).next() {
        if let Some(m) = RE_TITLE_YEAR.captures(&text_of(page_title)) {
            year = m.get(1).and_then(|g| g.as_str().parse().ok());
        }
    }

    let blurb = doc
        .select(&h_desc_sel)
        .next()
        .map(text_of)
        .filter(|s| !s.is_empty());

    let rel_root = doc.select(&rel_root_sel).next();

    let mut hero_attrs = HashMap::new();
    let mut hero_tags = HashMap::new();
    for el in doc.select(&attr_sel) {
        if rel_root.is_some_and(|root| is_descendant_of(el, root)) {
            continue;
        }
        collect_attrs(el, &mut hero_attrs, &mut hero_tags, &entry_sel, &value_sel);
    }

    let id_marker = format!("{id}.jpg");
    let hero_src = doc
        .select(&img_sel)
        .find(|img| {
            img.value()
                .attr("src")
                .is_some_and(|src| src.contains("/img/movie/thumb/") && src.contains(&id_marker))
        })
        .and_then(|img| img.value().attr("src"))
        .unwrap_or("");
    let hero_thumb = absolute_url(hero_src);

    let hero_rating = doc
        .select(&rat_rating_sel)
        .find(|el| !rel_root.is_some_and(|root| is_descendant_of(*el, root)))
        .and_then(|el| text_number(&text_of(el)).parse().ok());

    let hero_votes = doc
        .select(&rat_vote_sel)
        .find(|el| !rel_root.is_some_and(|root| is_descendant_of(*el, root)))
        .and_then(|el| clean_vote_count(&text_of(el)));

    let mut items = Vec::new();
    if let Some(rel_root) = rel_root {
        for node in rel_root.select(&item_sel) {
            let data_id = node
                .value()
                .attr("data-id")
                .and_then(|s| s.parse::<i64>().ok());
            let Some(data_id) = data_id else { continue };

            let Some(name_anchor) = node.select(&name_sel).next() else {
                continue;
            };
            let href = name_anchor.value().attr("href").unwrap_or("");
            let item_slug = href.trim_start_matches("/movies/").to_string();
            let label = text_of(name_anchor);

            let item_year = RE_YEAR_SUFFIX
                .captures(&label)
                .and_then(|c| c.get(1))
                .and_then(|m| m.as_str().parse().ok());
            let item_title = RE_YEAR_SUFFIX.replace(&label, "").trim().to_string();

            let rating_txt = node
                .select(&rat_rating_sel)
                .next()
                .map(text_of)
                .unwrap_or_default();
            let vote_txt = node
                .select(&rat_vote_sel)
                .next()
                .map(text_of)
                .unwrap_or_default();
            let img_src = node
                .select(&img_sel)
                .next()
                .and_then(|img| img.value().attr("src"))
                .unwrap_or("");
            let thumb = absolute_url(img_src);

            let sim_pct = node
                .select(&smt_sel)
                .next()
                .and_then(|el| {
                    text_of(el)
                        .replace('%', "")
                        .trim()
                        .parse::<i32>()
                        .ok()
                });

            let mut attr_map = HashMap::new();
            let mut tag_map = HashMap::new();
            for at in node.select(&attr_sel) {
                collect_attrs(at, &mut attr_map, &mut tag_map, &entry_sel, &value_sel);
            }

            items.push(SimilarItem {
                id: data_id,
                slug: item_slug,
                title: item_title,
                year: item_year,
                rating: text_number(&rating_txt).parse().ok(),
                vote_count: clean_vote_count(&vote_txt),
                thumb_url: thumb,
                similarity_percent: sim_pct,
                genre: attr_map.get("genre").cloned(),
                country: attr_map.get("country").cloned(),
                duration: attr_map.get("duration").cloned(),
                story: attr_map.get("story").cloned(),
                style_tags: tag_map.get("style").cloned().unwrap_or_default(),
                plot_tags: tag_map.get("plot").cloned().unwrap_or_default(),
                audience_tags: tag_map.get("audience").cloned().unwrap_or_default(),
                time_tags: tag_map.get("time").cloned().unwrap_or_default(),
                place_tags: tag_map.get("place").cloned().unwrap_or_default(),
            });
        }
    }

    items.sort_by(|a, b| {
        let av = a.similarity_percent.unwrap_or(-1);
        let bv = b.similarity_percent.unwrap_or(-1);
        bv.cmp(&av)
    });

    Some(Details {
        id,
        slug: slug.to_string(),
        title,
        year,
        rating: hero_rating,
        vote_count: hero_votes,
        thumb_url: hero_thumb,
        story: hero_attrs.get("story").cloned(),
        genre: hero_attrs.get("genre").cloned(),
        country: hero_attrs.get("country").cloned(),
        duration: hero_attrs.get("duration").cloned(),
        style_tags: hero_tags.get("style").cloned().unwrap_or_default(),
        plot_tags: hero_tags.get("plot").cloned().unwrap_or_default(),
        audience_tags: hero_tags.get("audience").cloned().unwrap_or_default(),
        time_tags: hero_tags.get("time").cloned().unwrap_or_default(),
        place_tags: hero_tags.get("place").cloned().unwrap_or_default(),
        blurb,
        similar: items,
    })
}

pub fn autocomplete_url(term: &str) -> String {
    format!(
        "{BASE_URL}/site/autocomplete?term={}",
        urlencoding::encode(term.trim())
    )
}

pub fn details_url(slug: &str) -> String {
    format!("{BASE_URL}/movies/{slug}")
}

#[cfg(test)]
mod tests {
    use super::*;

    const AUTOCOMPLETE_FIXTURE: &str = r#"{
        "movie": [
            {"id": "145", "label": "Sinister (2012)", "url": "/movies/145-sinister", "serial": "0"},
            {"id": "999", "label": "Sinister Squad (2016)", "url": "/movies/999-sinister-squad", "serial": "1"}
        ],
        "tag": []
    }"#;

    const DETAILS_FIXTURE: &str = r#"
<!DOCTYPE html>
<html>
<head><title>Sinister (2012) - BestSimilar</title></head>
<body>
  <h1>Movies Like Sinister</h1>
  <div class="h-desc">If you like Sinister you are looking for scary movies.</div>
  <img src="/img/movie/thumb/14/145.jpg" alt="Sinister">
  <div class="attr"><span class="entry">Genre:</span><span class="value">Horror</span></div>
  <div class="attr"><span class="entry">Country:</span><span class="value">USA</span></div>
  <div class="attr"><span class="entry">Duration:</span><span class="value">110 min</span></div>
  <div class="attr"><span class="entry">Story:</span><span class="value">A writer finds old home movies.</span></div>
  <div class="attr attr-tag"><span class="entry">Style:</span><span class="value">dark, creepy</span></div>
  <div class="rat-rating">6.8</div>
  <div class="rat-vote">(67K votes)</div>
  <div id="movie-rel-list">
    <div class="item item-movie" data-id="200">
      <a class="name" href="/movies/200-insidious">Insidious (2010)</a>
      <div class="rat-rating">6.8</div>
      <div class="rat-vote">(123K)</div>
      <img src="/img/movie/thumb/20/200.jpg">
      <div class="smt-value">92%</div>
      <div class="attr"><span class="entry">Genre:</span><span class="value">Horror</span></div>
      <div class="attr attr-tag"><span class="entry">Plot:</span><span class="value">haunted house</span></div>
    </div>
    <div class="item item-movie" data-id="201">
      <a class="name" href="/movies/201-the-conjuring">The Conjuring (2013)</a>
      <div class="smt-value">88%</div>
    </div>
  </div>
</body>
</html>
"#;

    #[test]
    fn parse_autocomplete_fixture() {
        let hits = parse_autocomplete_json(AUTOCOMPLETE_FIXTURE);
        assert_eq!(hits.len(), 2);

        assert_eq!(hits[0].id, 145);
        assert_eq!(hits[0].slug, "145-sinister");
        assert_eq!(hits[0].title, "Sinister");
        assert_eq!(hits[0].year, Some(2012));
        assert!(!hits[0].is_tv);

        assert_eq!(hits[1].id, 999);
        assert!(hits[1].is_tv);
    }

    #[test]
    fn parse_autocomplete_invalid_json() {
        assert!(parse_autocomplete_json("not json").is_empty());
        assert!(parse_autocomplete_json(r#"{"tag":[]}"#).is_empty());
    }

    #[test]
    fn parse_details_fixture() {
        let details = parse_details_html(145, "145-sinister", DETAILS_FIXTURE).expect("parse");
        assert_eq!(details.id, 145);
        assert_eq!(details.slug, "145-sinister");
        assert_eq!(details.title, "Sinister");
        assert_eq!(details.year, Some(2012));
        assert_eq!(details.rating, Some(6.8));
        assert_eq!(details.vote_count.as_deref(), Some("67K"));
        assert!(details
            .thumb_url
            .contains("/img/movie/thumb/14/145.jpg"));
        assert_eq!(details.genre.as_deref(), Some("Horror"));
        assert_eq!(details.country.as_deref(), Some("USA"));
        assert_eq!(details.duration.as_deref(), Some("110 min"));
        assert_eq!(
            details.story.as_deref(),
            Some("A writer finds old home movies.")
        );
        assert_eq!(details.style_tags, vec!["dark", "creepy"]);
        assert_eq!(
            details.blurb.as_deref(),
            Some("If you like Sinister you are looking for scary movies.")
        );

        assert_eq!(details.similar.len(), 2);
        assert_eq!(details.similar[0].id, 200);
        assert_eq!(details.similar[0].title, "Insidious");
        assert_eq!(details.similar[0].year, Some(2010));
        assert_eq!(details.similar[0].similarity_percent, Some(92));
        assert_eq!(details.similar[0].plot_tags, vec!["haunted house"]);
        assert_eq!(details.similar[1].similarity_percent, Some(88));
    }

    #[test]
    fn find_best_hit_scoring() {
        let hits = parse_autocomplete_json(AUTOCOMPLETE_FIXTURE);
        let best = find_best_hit(&hits, "Sinister", Some(2012), false);
        assert_eq!(best.map(|h| h.id), Some(145));

        let miss = find_best_hit(&hits, "Unknown Title", Some(1999), false);
        assert!(miss.is_none());
    }

    #[test]
    fn hero_attrs_outside_rel_list_only() {
        let html = r#"
        <html><head><title>Test (2020)</title></head><body>
        <div class="attr"><span class="entry">Genre:</span><span class="value">HeroGenre</span></div>
        <div id="movie-rel-list">
          <div class="attr"><span class="entry">Genre:</span><span class="value">ItemGenre</span></div>
        </div>
        </body></html>
        "#;
        let details = parse_details_html(1, "1-test", html).expect("parse");
        assert_eq!(details.genre.as_deref(), Some("HeroGenre"));
    }
}
