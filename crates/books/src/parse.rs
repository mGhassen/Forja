use regex::Regex;
use scraper::{ElementRef, Html, Selector};
use serde::Serialize;

use crate::http::BASE_URL;

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct DownloadLink {
    pub title: String,
    pub href: String,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct BookResult {
    pub title: String,
    pub series: String,
    pub author: String,
    pub publisher: String,
    pub year: String,
    pub language: String,
    pub pages: String,
    pub size: String,
    pub format: String,
    pub isbn: String,
    pub edition_id: String,
    pub edition_url: String,
    pub file_id: String,
    pub download_links: Vec<DownloadLink>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct BookEditionDetails {
    pub edition_id: String,
    pub md5: String,
    pub ads_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub size: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub extension: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pages: Option<String>,
}

fn text_of(el: ElementRef<'_>) -> String {
    el.text().collect::<String>().trim().to_string()
}

pub fn parse_search_results(html: &str) -> Vec<BookResult> {
    let doc = Html::parse_document(html);
    let row_sel = Selector::parse("table tbody tr, table tr").unwrap();
    let td_sel = Selector::parse("td").unwrap();
    let title_link_sel = Selector::parse("a[href*=\"edition.php\"]").unwrap();
    let series_sel = Selector::parse("b").unwrap();
    let isbn_sel = Selector::parse("font[color=\"green\"]").unwrap();
    let file_id_sel = Selector::parse(".badge-secondary").unwrap();
    let size_a_sel = Selector::parse("a").unwrap();
    let dl_a_sel = Selector::parse("a").unwrap();
    let badge_sel = Selector::parse(".badge").unwrap();
    let edition_id_re = Regex::new(r"id=(\d+)").unwrap();

    let mut results = Vec::new();

    for row in doc.select(&row_sel) {
        let tds: Vec<_> = row.select(&td_sel).collect();
        if tds.len() < 8 {
            continue;
        }

        let first_td = tds[0];
        let Some(title_link) = first_td.select(&title_link_sel).next() else {
            continue;
        };

        let title = text_of(title_link);
        if title.is_empty() {
            continue;
        }

        let edition_href = title_link.value().attr("href").unwrap_or("");
        let Some(edition_id) = edition_id_re
            .captures(edition_href)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().to_string())
            .filter(|s| !s.is_empty())
        else {
            continue;
        };

        let series = first_td
            .select(&series_sel)
            .next()
            .map(text_of)
            .unwrap_or_default();
        let isbn = first_td
            .select(&isbn_sel)
            .next()
            .map(text_of)
            .unwrap_or_default();
        let file_id = first_td
            .select(&file_id_sel)
            .next()
            .map(text_of)
            .unwrap_or_default();

        let author = text_of(tds[1]);
        let publisher = text_of(tds[2]);
        let year = text_of(tds[3]);
        let language = text_of(tds[4]);
        let pages = text_of(tds[5]);

        let size_td = tds[6];
        let size = size_td
            .select(&size_a_sel)
            .next()
            .map(text_of)
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| text_of(size_td));

        let format = text_of(tds[7]);
        if format.to_lowercase() != "epub" {
            continue;
        }

        let mut download_links = Vec::new();
        if tds.len() > 8 {
            let dl_td = tds[8];
            for a in dl_td.select(&dl_a_sel) {
                let href = a.value().attr("href").unwrap_or("").to_string();
                if href.is_empty() {
                    continue;
                }
                let link_title = a
                    .value()
                    .attr("data-original-title")
                    .map(str::to_string)
                    .filter(|s| !s.is_empty())
                    .or_else(|| a.select(&badge_sel).next().map(text_of))
                    .unwrap_or_default();
                download_links.push(DownloadLink {
                    title: link_title,
                    href,
                });
            }
        }

        results.push(BookResult {
            title,
            series,
            author,
            publisher,
            year,
            language,
            pages,
            size,
            format,
            isbn,
            edition_id: edition_id.clone(),
            edition_url: format!("{BASE_URL}/edition.php?id={edition_id}"),
            file_id,
            download_links,
        });
    }

    results
}

pub fn parse_edition_details(html: &str, edition_id: &str) -> Result<BookEditionDetails, String> {
    let doc = Html::parse_document(html);
    let ads_link_sel = Selector::parse("a[href^=\"ads.php?md5=\"]").unwrap();
    let table_row_sel = Selector::parse("table#tablelibgen tr").unwrap();
    let td_sel = Selector::parse("td").unwrap();
    let md5_re = Regex::new(r"md5=([a-f0-9]+)").unwrap();
    let size_re = Regex::new(r"Size:\s*([^\n]+)").unwrap();
    let ext_re = Regex::new(r"Extension:\s*(\w+)").unwrap();
    let pages_re = Regex::new(r"Pages:\s*(\d+)").unwrap();

    let ads_href = doc
        .select(&ads_link_sel)
        .next()
        .and_then(|a| a.value().attr("href"))
        .unwrap_or("");

    let md5 = md5_re
        .captures(ads_href)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| format!("MD5 not found for edition {edition_id}"))?;

    let mut size = None;
    let mut extension = None;
    let mut pages = None;

    for row in doc.select(&table_row_sel) {
        let tds: Vec<_> = row.select(&td_sel).collect();
        if tds.len() < 2 {
            continue;
        }
        let text = text_of(tds[1]);

        if size.is_none() {
            if let Some(m) = size_re.captures(&text) {
                size = m.get(1).map(|v| v.as_str().trim().to_string());
            }
        }
        if extension.is_none() {
            if let Some(m) = ext_re.captures(&text) {
                extension = m.get(1).map(|v| v.as_str().trim().to_string());
            }
        }
        if pages.is_none() {
            if let Some(m) = pages_re.captures(&text) {
                pages = m.get(1).map(|v| v.as_str().trim().to_string());
            }
        }
    }

    Ok(BookEditionDetails {
        edition_id: edition_id.to_string(),
        md5: md5.clone(),
        ads_url: format!("{BASE_URL}/ads.php?md5={md5}"),
        size,
        extension,
        pages,
    })
}

pub fn parse_download_url(html: &str) -> Result<String, String> {
    let doc = Html::parse_document(html);
    let get_link_sel = Selector::parse("table#main a[href^=\"get.php\"]").unwrap();

    let get_link = doc
        .select(&get_link_sel)
        .next()
        .and_then(|a| a.value().attr("href"))
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "get.php link not found".to_string())?;

    Ok(format!("{BASE_URL}/{get_link}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    const SEARCH_FIXTURE: &str = r#"
    <table>
      <tbody>
        <tr>
          <td>
            <a href="edition.php?id=12345">Test Book</a>
            <b>Series Name</b>
            <font color="green">978-0-123456-78-9</font>
            <span class="badge-secondary">FILE99</span>
          </td>
          <td>Jane Author</td>
          <td>Test Publisher</td>
          <td>2024</td>
          <td>English</td>
          <td>300</td>
          <td><a>1.2 MB</a></td>
          <td>epub</td>
          <td>
            <a href="https://mirror.example/dl" data-original-title="Mirror 1">
              <span class="badge">M1</span>
            </a>
          </td>
        </tr>
        <tr>
          <td><a href="edition.php?id=999">PDF Only</a></td>
          <td>A</td><td>B</td><td>2020</td><td>en</td><td>100</td><td>2 MB</td><td>pdf</td>
        </tr>
      </tbody>
    </table>
    "#;

    const EDITION_FIXTURE: &str = r#"
    <a href="ads.php?md5=abcdef0123456789abcdef0123456789">Download</a>
    <table id="tablelibgen">
      <tr><td>Label</td><td>Size: 1.5 MB</td></tr>
      <tr><td>Label</td><td>Extension: epub</td></tr>
      <tr><td>Label</td><td>Pages: 412</td></tr>
    </table>
    "#;

    const ADS_FIXTURE: &str = r#"
    <table id="main">
      <tr>
        <td><a href="get.php?md5=abcdef0123456789abcdef0123456789&amp;key=SECRET">GET</a></td>
      </tr>
    </table>
    "#;

    #[test]
    fn parse_search_keeps_epub_only() {
        let results = parse_search_results(SEARCH_FIXTURE);
        assert_eq!(results.len(), 1);
        let book = &results[0];
        assert_eq!(book.title, "Test Book");
        assert_eq!(book.series, "Series Name");
        assert_eq!(book.author, "Jane Author");
        assert_eq!(book.publisher, "Test Publisher");
        assert_eq!(book.year, "2024");
        assert_eq!(book.language, "English");
        assert_eq!(book.pages, "300");
        assert_eq!(book.size, "1.2 MB");
        assert_eq!(book.format, "epub");
        assert_eq!(book.isbn, "978-0-123456-78-9");
        assert_eq!(book.edition_id, "12345");
        assert_eq!(book.edition_url, "https://libgen.li/edition.php?id=12345");
        assert_eq!(book.file_id, "FILE99");
        assert_eq!(book.download_links.len(), 1);
        assert_eq!(book.download_links[0].title, "Mirror 1");
        assert_eq!(book.download_links[0].href, "https://mirror.example/dl");
    }

    #[test]
    fn parse_edition_extracts_md5_and_metadata() {
        let details = parse_edition_details(EDITION_FIXTURE, "12345").unwrap();
        assert_eq!(details.edition_id, "12345");
        assert_eq!(details.md5, "abcdef0123456789abcdef0123456789");
        assert_eq!(
            details.ads_url,
            "https://libgen.li/ads.php?md5=abcdef0123456789abcdef0123456789"
        );
        assert_eq!(details.size.as_deref(), Some("1.5 MB"));
        assert_eq!(details.extension.as_deref(), Some("epub"));
        assert_eq!(details.pages.as_deref(), Some("412"));
    }

    #[test]
    fn parse_edition_errors_without_md5() {
        let err = parse_edition_details("<html></html>", "42").unwrap_err();
        assert!(err.contains("MD5 not found"));
    }

    #[test]
    fn parse_download_url_from_ads_page() {
        let url = parse_download_url(ADS_FIXTURE).unwrap();
        assert_eq!(
            url,
            "https://libgen.li/get.php?md5=abcdef0123456789abcdef0123456789&key=SECRET"
        );
    }

    #[test]
    fn parse_download_url_errors_when_missing() {
        let err = parse_download_url("<html></html>").unwrap_err();
        assert!(err.contains("get.php link not found"));
    }
}
