use std::collections::HashMap;

use stremio::fetch_post_with_headers_unchecked;

const GQL_URL: &str = "https://graphql.anilist.co";

/// POST a GraphQL query to AniList. Returns the raw JSON response body on HTTP 200.
pub fn query_json(query: &str, variables_json: &str) -> String {
    let variables: serde_json::Value =
        serde_json::from_str(variables_json).unwrap_or_else(|_| serde_json::json!({}));
    let body = serde_json::json!({
        "query": query,
        "variables": variables,
    })
    .to_string();

    let mut headers = HashMap::new();
    headers.insert("Accept".into(), "application/json".into());
    headers.insert("Content-Type".into(), "application/json".into());

    match fetch_post_with_headers_unchecked(GQL_URL, 15, &headers, &body) {
        Ok(resp) if resp.status == 200 => resp.body,
        Ok(resp) => serde_json::json!({
            "error": format!("AniList HTTP {}", resp.status),
            "status": resp.status,
            "body": resp.body,
        })
        .to_string(),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn query_trending_smoke() {
        let q = r#"query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }"#;
        let body = query_json(q, "{}");
        assert!(body.contains("\"data\""));
        assert!(!body.contains("\"error\""));
    }
}
