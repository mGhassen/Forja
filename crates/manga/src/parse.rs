use regex::Regex;
use scraper::{ElementRef, Html, Selector};
use serde::Serialize;

use crate::http::COVER_CDN;

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct MangaCard {
    pub id: String,
    pub title: String,
    pub cover_small: String,
    pub cover_normal: String,
    #[serde(default)]
    pub r#type: String,
    #[serde(default)]
    pub url: String,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct MangaDetails {
    pub id: String,
    pub title: String,
    pub cover_small: String,
    pub cover_normal: String,
    #[serde(default)]
    pub r#type: String,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub year: String,
    #[serde(default)]
    pub author: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub synopsis: String,
    #[serde(default)]
    pub url: String,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct MangaChapterOut {
    pub id: String,
    pub number: f64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub raw_name: String,
}

fn series_id_from_url(url: &str) -> Option<String> {
    Regex::new(r"/series/([A-Z0-9]{26})")
        .ok()?
        .captures(url)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string())
}

fn chapter_id_from_url(url: &str) -> Option<String> {
    Regex::new(r"/chapters/([A-Z0-9]{26})")
        .ok()?
        .captures(url)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string())
}

fn text_of(el: ElementRef<'_>) -> String {
    el.text().collect::<String>().trim().to_string()
}

pub fn parse_search_results(html: &str) -> Vec<MangaCard> {
    let doc = Html::parse_document(html);
    let article_sel = Selector::parse("article").unwrap();
    let series_link_sel = Selector::parse("a[href*=\"/series/\"]").unwrap();
    let img_sel = Selector::parse("img").unwrap();
    let truncate_sel = Selector::parse(".truncate").unwrap();
    let line_clamp_sel = Selector::parse(".line-clamp-1").unwrap();
    let data_tip_sel = Selector::parse("[data-tip]").unwrap();

    let mut results = Vec::new();
    for article in doc.select(&article_sel) {
        let Some(series_link) = article.select(&series_link_sel).next() else {
            continue;
        };
        let href = series_link.value().attr("href").unwrap_or("").to_string();
        let Some(series_id) = series_id_from_url(&href) else {
            continue;
        };

        let mut title = String::new();
        if let Some(img) = article.select(&img_sel).next() {
            if let Some(alt) = img.value().attr("alt") {
                if alt.ends_with(" cover") {
                    title = alt[..alt.len() - 6].to_string();
                }
            }
        }
        if title.is_empty() {
            title = article
                .select(&truncate_sel)
                .next()
                .map(text_of)
                .filter(|t| !t.is_empty())
                .or_else(|| {
                    article
                        .select(&line_clamp_sel)
                        .next()
                        .map(text_of)
                        .filter(|t| !t.is_empty())
                })
                .unwrap_or_else(|| {
                    text_of(series_link)
                        .lines()
                        .next()
                        .unwrap_or("")
                        .trim()
                        .to_string()
                });
        }

        let mut manga_type = String::new();
        for el in article.select(&data_tip_sel) {
            if let Some(tip) = el.value().attr("data-tip") {
                if ["Manga", "Manhwa", "Manhua", "OEL"].contains(&tip) {
                    manga_type = tip.to_string();
                    break;
                }
            }
        }

        results.push(MangaCard {
            id: series_id.clone(),
            title,
            cover_small: format!("{COVER_CDN}/small/{series_id}.webp"),
            cover_normal: format!("{COVER_CDN}/normal/{series_id}.webp"),
            r#type: manga_type,
            url: href,
        });
    }
    results
}

pub fn parse_series_detail(html: &str, series_id: &str) -> MangaDetails {
    let doc = Html::parse_document(html);
    let h1_sel = Selector::parse("h1").unwrap();
    let li_sel = Selector::parse("li").unwrap();
    let strong_sel = Selector::parse("strong").unwrap();
    let a_sel = Selector::parse("a").unwrap();
    let span_sel = Selector::parse("span").unwrap();
    let p_sel = Selector::parse("p").unwrap();

    let title = doc.select(&h1_sel).next().map(text_of).unwrap_or_default();

    let mut details: std::collections::HashMap<String, Vec<String>> =
        std::collections::HashMap::new();
    for li in doc.select(&li_sel) {
        let Some(strong) = li.select(&strong_sel).next() else {
            continue;
        };
        let label = text_of(strong)
            .replace(':', "")
            .replace("(s)", "")
            .trim()
            .to_string();
        let links: Vec<String> = li
            .select(&a_sel)
            .map(text_of)
            .filter(|t| !t.is_empty())
            .collect();
        if !links.is_empty() {
            details.insert(label, links);
        } else {
            let spans: Vec<String> = li
                .select(&span_sel)
                .map(text_of)
                .filter(|t| !t.is_empty())
                .collect();
            if !spans.is_empty() {
                details.insert(label, spans);
            }
        }
    }

    let mut synopsis = String::new();
    for p in doc.select(&p_sel) {
        let text = text_of(p);
        if text.len() > 50 && !text.contains("Copyright") && !text.contains("verified") {
            synopsis = text;
            break;
        }
    }

    MangaDetails {
        id: series_id.to_string(),
        title,
        cover_small: format!("{COVER_CDN}/small/{series_id}.webp"),
        cover_normal: format!("{COVER_CDN}/normal/{series_id}.webp"),
        r#type: details.get("Type").and_then(|v| v.first()).cloned().unwrap_or_default(),
        status: details
            .get("Status")
            .and_then(|v| v.first())
            .cloned()
            .unwrap_or_default(),
        year: details
            .get("Released")
            .and_then(|v| v.first())
            .cloned()
            .unwrap_or_default(),
        author: details.get("Author").cloned().unwrap_or_default().join(", "),
        tags: details.get("Tag").cloned().unwrap_or_default(),
        synopsis,
        url: format!("/series/{series_id}"),
    }
}

fn chapter_from_raw(id: &str, raw_name: &str, url: &str) -> MangaChapterOut {
    let mut cleaned = raw_name.trim().to_string();
    if cleaned.to_lowercase().starts_with("chapter") {
        cleaned = cleaned[7..].trim().to_string();
    }

    let sep_re = Regex::new(r"[:\-–]").expect("chapter sep");
    let (number_str, name) = if let Some(m) = sep_re.find(&cleaned) {
        let idx = m.start();
        (
            cleaned[..idx].trim().to_string(),
            cleaned[idx + m.len()..].trim().to_string(),
        )
    } else {
        (cleaned.clone(), String::new())
    };

    let number = number_str.parse::<f64>().unwrap_or(0.0);
    MangaChapterOut {
        id: id.to_string(),
        number,
        name,
        url: url.to_string(),
        raw_name: raw_name.to_string(),
    }
}

pub fn parse_chapters(html: &str) -> Vec<MangaChapterOut> {
    let doc = Html::parse_document(html);
    let link_sel = Selector::parse("a[href*=\"/chapters/\"]").unwrap();
    let span_sel = Selector::parse("span").unwrap();

    let mut chapters = Vec::new();
    for a in doc.select(&link_sel) {
        let href = a.value().attr("href").unwrap_or("").to_string();
        let Some(chapter_id) = chapter_id_from_url(&href) else {
            continue;
        };
        let mut chapter_name = String::new();
        for span in a.select(&span_sel) {
            let t = text_of(span);
            if !t.is_empty()
                && !t.contains('{')
                && !t.contains(".st0")
                && !t.contains("fill:")
            {
                chapter_name = t;
                break;
            }
        }
        if !chapter_name.is_empty() {
            chapters.push(chapter_from_raw(&chapter_id, &chapter_name, &href));
        }
    }
    chapters
}

pub fn parse_chapter_images(html: &str) -> Vec<String> {
    let doc = Html::parse_document(html);
    let img_sel = Selector::parse("img").unwrap();
    let mut images = Vec::new();
    for img in doc.select(&img_sel) {
        let src = img.value().attr("src").unwrap_or("").to_string();
        if !src.is_empty() && !src.contains("/static/") && !src.contains("brand") {
            images.push(src);
        }
    }
    images
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn chapter_from_raw_splits_title() {
        let ch = chapter_from_raw("ABC", "Chapter 12: The End", "/chapters/ABC");
        assert_eq!(ch.number, 12.0);
        assert_eq!(ch.name, "The End");
    }
}
