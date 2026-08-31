use std::collections::HashMap;

use stremio::{fetch_get_with_headers, fetch_post_with_headers};

pub fn get(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Result<(u16, String), String> {
    let resp = fetch_get_with_headers(url, timeout_secs, headers)?;
    Ok((resp.status, resp.body))
}

pub fn post(
    url: &str,
    headers: &HashMap<String, String>,
    body: &str,
    timeout_secs: u64,
) -> Result<(u16, String), String> {
    let resp = fetch_post_with_headers(url, timeout_secs, headers, body)?;
    Ok((resp.status, resp.body))
}
