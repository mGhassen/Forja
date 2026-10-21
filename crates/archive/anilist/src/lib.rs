use std::collections::HashMap;

use stremio::fetch_post_with_headers_unchecked;

const GQL_URL: &str = "https://graphql.anilist.co";
/// Offline AniList catalog — tried when graphql.anilist.co is down.
const GQL_MIRRORS: &[&str] = &["https://graphql.aniraku.tech/"];

const DEFAULT_UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

fn gql_headers() -> HashMap<String, String> {
    HashMap::from([
        ("Accept".into(), "application/json".into()),
        ("Content-Type".into(), "application/json".into()),
        ("User-Agent".into(), DEFAULT_UA.into()),
        ("Origin".into(), "https://anilist.co".into()),
        ("Referer".into(), "https://anilist.co/".into()),
    ])
}

fn gql_endpoints() -> impl Iterator<Item = &'static str> {
    std::iter::once(GQL_URL).chain(GQL_MIRRORS.iter().copied())
}

fn is_success_body(body: &str) -> bool {
    body.contains("\"data\"") && !body.contains("\"error\"")
}

fn looks_like_outage(status: u16, body: &str) -> bool {
    if matches!(status, 403 | 429 | 502 | 503 | 504) || status >= 500 {
        return true;
    }
    let lower = body.to_ascii_lowercase();
    lower.contains("temporarily disabled")
        || lower.contains("stability issues")
        || lower.contains("too many requests")
}

/// POST a GraphQL query to AniList (then mirrors). Returns raw JSON on success.
pub fn query_json(query: &str, variables_json: &str) -> String {
    let variables: serde_json::Value =
        serde_json::from_str(variables_json).unwrap_or_else(|_| serde_json::json!({}));
    let body = serde_json::json!({
        "query": query,
        "variables": variables,
    })
    .to_string();

    let headers = gql_headers();
    let mut last = serde_json::json!({ "error": "AniList unreachable" }).to_string();

    for url in gql_endpoints() {
        match fetch_post_with_headers_unchecked(url, 15, &headers, &body) {
            Ok(resp) if resp.status == 200 && is_success_body(&resp.body) => {
                return resp.body;
            }
            Ok(resp) if looks_like_outage(resp.status, &resp.body) => {
                last = serde_json::json!({
                    "error": format!("AniList HTTP {}", resp.status),
                    "status": resp.status,
                    "body": resp.body,
                    "url": url,
                })
                .to_string();
                continue;
            }
            Ok(resp) if resp.status == 200 => {
                // GraphQL payload without usable data — still try mirrors.
                if resp.body.contains("\"data\"") {
                    return resp.body;
                }
                last = serde_json::json!({
                    "error": "AniList empty",
                    "status": resp.status,
                    "body": resp.body,
                    "url": url,
                })
                .to_string();
                continue;
            }
            Ok(resp) => {
                last = serde_json::json!({
                    "error": format!("AniList HTTP {}", resp.status),
                    "status": resp.status,
                    "body": resp.body,
                    "url": url,
                })
                .to_string();
                continue;
            }
            Err(e) => {
                last = serde_json::json!({ "error": e, "url": url }).to_string();
                continue;
            }
        }
    }

    last
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn query_trending_smoke() {
        let q = r#"query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }"#;
        let body = query_json(q, "{}");
        assert!(
            body.contains("\"data\""),
            "expected data from AniList or mirror, got: {body}"
        );
        assert!(!body.contains("\"error\""), "unexpected error body: {body}");
    }
}
