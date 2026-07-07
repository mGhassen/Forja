use quick_xml::events::Event;
use quick_xml::name::QName;
use quick_xml::reader::Reader;

use crate::http::{block_on, client};
use crate::types::{format_size, normalize_base_url, ConnectionTest, TorrentRow};

const CATEGORIES: &str = "2000,5000,5030,5040,5045,2010,2020,2030,2040,2045";
const TIMEOUT_SECS: u64 = 20;
const TEST_TIMEOUT_SECS: u64 = 10;

pub async fn search(base_url: &str, api_key: &str, query: &str) -> Result<Vec<TorrentRow>, String> {
    let normalized = normalize_base_url(base_url);
    let url = format!(
        "{normalized}/api/v2.0/indexers/all/results/torznab/api?apikey={}&t=search&q={}&cat={}",
        urlencoding::encode(api_key),
        urlencoding::encode(query),
        CATEGORIES
    );

    let http = client(std::time::Duration::from_secs(TIMEOUT_SECS))?;
    let response = http.get(&url).send().await.map_err(|e| {
        if e.is_timeout() {
            "⚠️ Jackett timed out. It may be overloaded or the URL is wrong.".into()
        } else if e.is_connect() {
            "⚠️ Cannot connect to Jackett. Is it running? Check your Base URL in Settings.".into()
        } else {
            format!("⚠️ Unexpected error: {e}")
        }
    })?;

    let status = response.status().as_u16();
    let body = response.text().await.map_err(|e| e.to_string())?;

    if status == 401 || body.contains("Unauthorized") {
        return Err("❌ Invalid API Key. Check your Jackett API key in Settings.".into());
    }
    if status == 403 {
        return Err("❌ Access denied. Check your Jackett API key and server configuration.".into());
    }
    if status == 500 {
        return Err("❌ Jackett returned a server error. Check the Jackett logs.".into());
    }
    if status != 200 {
        return Err(format!("❌ Jackett returned HTTP {status}"));
    }

    parse_torznab_xml(&body)
}

pub async fn test_connection(base_url: &str, api_key: &str) -> ConnectionTest {
    let normalized = normalize_base_url(base_url);
    let url = format!(
        "{normalized}/api/v2.0/indexers/all/results/torznab/api?apikey={}&t=indexers&configured=true",
        urlencoding::encode(api_key)
    );

    let http = match client(std::time::Duration::from_secs(TEST_TIMEOUT_SECS)) {
        Ok(c) => c,
        Err(e) => {
            return ConnectionTest {
                success: false,
                message: format!("❌ Error: {e}"),
                indexer_count: None,
                version: None,
            };
        }
    };

    let response = match http.get(&url).send().await {
        Ok(r) => r,
        Err(e) => {
            let msg = if e.is_timeout() {
                "❌ Connection timed out"
            } else if e.is_connect() {
                "❌ Cannot connect to Jackett"
            } else {
                return ConnectionTest {
                    success: false,
                    message: format!("❌ Error: {e}"),
                    indexer_count: None,
                    version: None,
                };
            };
            return ConnectionTest {
                success: false,
                message: msg.into(),
                indexer_count: None,
                version: None,
            };
        }
    };

    let status = response.status().as_u16();
    let body = response.text().await.unwrap_or_default();

    if status == 401 || body.contains("Unauthorized") {
        return ConnectionTest {
            success: false,
            message: "❌ Wrong API key".into(),
            indexer_count: None,
            version: None,
        };
    }

    if status == 200 {
        if let Ok(count) = count_indexers(&body) {
            return ConnectionTest {
                success: true,
                message: format!("✅ Connected — {count} indexers configured"),
                indexer_count: Some(count),
                version: None,
            };
        }
        return ConnectionTest {
            success: true,
            message: "✅ Connected".into(),
            indexer_count: None,
            version: None,
        };
    }

    ConnectionTest {
        success: false,
        message: format!("❌ HTTP {status}"),
        indexer_count: None,
        version: None,
    }
}

pub fn search_blocking(base_url: &str, api_key: &str, query: &str) -> Result<Vec<TorrentRow>, String> {
    utils::engine_cancel::enter_job();
    block_on(search(base_url, api_key, query))
}

pub fn test_connection_blocking(base_url: &str, api_key: &str) -> ConnectionTest {
    utils::engine_cancel::enter_job();
    block_on(test_connection(base_url, api_key))
}

fn count_indexers(xml: &str) -> Result<u32, ()> {
    let mut reader = Reader::from_str(xml);
    reader.config_mut().trim_text(true);
    let mut count = 0u32;
    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) if e.name() == QName(b"indexer") => count += 1,
            Ok(Event::Eof) => break,
            Err(_) => return Err(()),
            _ => {}
        }
    }
    Ok(count)
}

fn parse_torznab_xml(xml_body: &str) -> Result<Vec<TorrentRow>, String> {
    let mut reader = Reader::from_str(xml_body);
    reader.config_mut().trim_text(true);

    let mut results = Vec::new();
    let mut in_item = false;
    let mut title = String::new();
    let mut size: i64 = 0;
    let mut seeders = String::from("0");
    let mut magnet_url: Option<String> = None;
    let mut info_hash: Option<String> = None;
    let mut link: Option<String> = None;
    let mut enclosure_url: Option<String> = None;
    let mut indexer = String::from("Jackett");
    let mut current_element = String::new();

    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) | Ok(Event::Empty(e)) => {
                let local = e.local_name();
                let name = std::str::from_utf8(local.as_ref()).unwrap_or("");
                if name == "item" {
                    in_item = true;
                    title.clear();
                    size = 0;
                    seeders = "0".into();
                    magnet_url = None;
                    info_hash = None;
                    link = None;
                    enclosure_url = None;
                    indexer = "Jackett".into();
                } else if in_item {
                    if name == "enclosure" {
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"url" {
                                enclosure_url =
                                    Some(String::from_utf8_lossy(&attr.value).into_owned());
                            } else if attr.key.as_ref() == b"length" {
                                if let Ok(s) =
                                    String::from_utf8_lossy(&attr.value).parse::<i64>()
                                {
                                    size = s;
                                }
                            }
                        }
                    } else if name == "attr" {
                        let mut attr_name = None;
                        let mut attr_value = None;
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"name" {
                                attr_name =
                                    Some(String::from_utf8_lossy(&attr.value).into_owned());
                            } else if attr.key.as_ref() == b"value" {
                                attr_value =
                                    Some(String::from_utf8_lossy(&attr.value).into_owned());
                            }
                        }
                        if let (Some(n), Some(v)) = (attr_name, attr_value) {
                            match n.as_str() {
                                "seeders" => seeders = v,
                                "magneturl" if v.starts_with("magnet:") => magnet_url = Some(v),
                                "infohash" => info_hash = Some(v),
                                _ => {}
                            }
                        }
                    } else {
                        current_element = name.to_string();
                    }
                }
            }
            Ok(Event::Text(t)) if in_item => {
                let text = t.unescape().unwrap_or_default().into_owned();
                match current_element.as_str() {
                    "title" => title = text,
                    "size" => size = text.parse().unwrap_or(size),
                    "link" => link = Some(text),
                    "jackettindexer" => indexer = text,
                    _ => {}
                }
            }
            Ok(Event::End(e)) => {
                let local = e.local_name();
                let name = std::str::from_utf8(local.as_ref()).unwrap_or("");
                if name == "item" && in_item {
                    in_item = false;
                    let mut download_link = magnet_url.clone();
                    if download_link.is_none() {
                        if let Some(ref u) = enclosure_url {
                            if u.starts_with("magnet:") {
                                download_link = Some(u.clone());
                            }
                        }
                    }
                    if download_link.is_none() {
                        download_link = link.clone();
                    }
                    if download_link.is_none() {
                        if let Some(ref hash) = info_hash {
                            if !hash.is_empty() {
                                download_link = Some(format!(
                                    "magnet:?xt=urn:btih:{hash}&dn={}",
                                    urlencoding::encode(&title)
                                ));
                            }
                        }
                    }
                    if let Some(dl) = download_link {
                        if !dl.is_empty() {
                            results.push(TorrentRow {
                                name: if title.is_empty() {
                                    "Unknown".into()
                                } else {
                                    title.clone()
                                },
                                magnet: dl,
                                seeders: seeders.clone(),
                                size: format_size(size),
                                source: indexer.clone(),
                            });
                        }
                    }
                }
                current_element.clear();
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(format!("⚠️ Unexpected response from Jackett. The server may be misconfigured. ({e})")),
            _ => {}
        }
    }

    Ok(results)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_torznab_item_with_magnet_attr() {
        let xml = r#"<?xml version="1.0"?>
<rss><channel><item>
<title>Test Movie 1080p</title>
<size>1073741824</size>
<torznab:attr name="seeders" value="42"/>
<torznab:attr name="magneturl" value="magnet:?xt=urn:btih:abc"/>
<jackettindexer>YTS</jackettindexer>
</item></channel></rss>"#;
        let rows = parse_torznab_xml(xml).unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].name, "Test Movie 1080p");
        assert_eq!(rows[0].seeders, "42");
        assert!(rows[0].magnet.starts_with("magnet:"));
        assert_eq!(rows[0].source, "YTS");
    }
}
