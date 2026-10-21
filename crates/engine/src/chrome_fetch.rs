//! Chrome TLS-impersonated HTTP for hosts that JA3-block plain reqwest (e.g. Dailymotion CDN).
//!
//! Same guard as [`crate::fetch_guard::guarded_fetch`]: every hop is resolved
//! and checked, redirects are followed by hand, the body stops at the cap.

use std::collections::HashMap;

use futures_util::StreamExt;
use serde_json::Value;
use url::Url;
use wreq::Client;
use wreq_util::Emulation;

use utils::engine_cancel::cancellation_token;

use crate::fetch_guard::{
    content_length_too_large, drop_sensitive_headers, fetch_cancelled_json, fetch_deadline,
    fetch_error_json, is_cross_host, next_redirect_hop, push_capped, resolve_checked,
    strip_forbidden_headers, FETCH_TIMEOUT, MAX_REDIRECTS, MAX_RESPONSE_BYTES,
};

fn headers_to_json(headers: &wreq::header::HeaderMap) -> serde_json::Map<String, Value> {
    let mut hdrs = serde_json::Map::new();
    for (k, v) in headers.iter() {
        if let Ok(s) = v.to_str() {
            hdrs.insert(k.to_string(), Value::String(s.to_string()));
        }
    }
    hdrs
}

/// Same JSON envelope as [`super::extract`]'s `__native_fetch`, but with Chrome TLS/HTTP2 fingerprint.
pub async fn chrome_fetch(
    url: String,
    method: String,
    headers_json: String,
    body: String,
    allow_local: bool,
) -> String {
    let token = cancellation_token();
    if token.is_cancelled() {
        return fetch_cancelled_json(&url);
    }
    let deadline = fetch_deadline();
    let mut headers: HashMap<String, String> =
        serde_json::from_str(&headers_json).unwrap_or_default();
    strip_forbidden_headers(&mut headers);
    let mut current = match Url::parse(&url) {
        Ok(u) => u,
        Err(e) => return fetch_error_json(&url, format!("invalid url: {e}")),
    };
    let mut method_up = method.to_ascii_uppercase();
    let mut send_body = !body.is_empty() && method_up != "GET" && method_up != "HEAD";
    let mut hops = 0usize;

    loop {
        if token.is_cancelled() {
            return fetch_cancelled_json(&url);
        }
        let (host, addrs) = match resolve_checked(&current, allow_local).await {
            Ok(v) => v,
            Err(msg) => return fetch_error_json(&url, msg),
        };
        let mut builder = Client::builder()
            .emulation(Emulation::Chrome137)
            .timeout(FETCH_TIMEOUT)
            .redirect(wreq::redirect::Policy::none());
        if !addrs.is_empty() {
            builder = builder.resolve_to_addrs(host.clone(), addrs.iter().copied());
        }
        let client = match builder.build() {
            Ok(c) => c,
            Err(e) => return fetch_error_json(&url, e),
        };
        let method = wreq::Method::from_bytes(method_up.as_bytes()).unwrap_or(wreq::Method::GET);
        let mut req = client.request(method, current.as_str());
        for (k, v) in &headers {
            req = req.header(k.as_str(), v.as_str());
        }
        if send_body {
            req = req.body(body.clone());
        }
        let resp = tokio::select! {
            r = tokio::time::timeout_at(deadline, req.send()) => match r {
                Ok(Ok(r)) => r,
                Ok(Err(e)) => return fetch_error_json(&url, e),
                Err(_) => return fetch_error_json(&url, "timed out"),
            },
            _ = token.cancelled() => return fetch_cancelled_json(&url),
        };

        let status = resp.status().as_u16();
        let location = resp
            .headers()
            .get(wreq::header::LOCATION)
            .and_then(|v| v.to_str().ok())
            .map(str::to_owned);
        if let Some(hop) = next_redirect_hop(status, location.as_deref(), &current, &method_up) {
            hops += 1;
            if hops > MAX_REDIRECTS {
                return fetch_error_json(&url, "too many redirects");
            }
            if is_cross_host(&current, &hop.url) {
                drop_sensitive_headers(&mut headers);
            }
            send_body = send_body && hop.keep_body;
            method_up = hop.method;
            current = hop.url;
            continue;
        }

        let final_url = resp.uri().to_string();
        let hdrs = headers_to_json(resp.headers());
        if method_up == "HEAD" {
            return crate::extract::pack_http_envelope(status, final_url, hdrs, Vec::new());
        }
        if content_length_too_large(resp.content_length()) {
            return fetch_error_json(
                &url,
                format!("response too large (over {} bytes)", MAX_RESPONSE_BYTES),
            );
        }
        let mut stream = resp.bytes_stream();
        let mut bytes: Vec<u8> = Vec::new();
        loop {
            let chunk = tokio::select! {
                c = tokio::time::timeout_at(deadline, stream.next()) => match c {
                    Ok(Some(Ok(c))) => Some(c),
                    Ok(Some(Err(e))) => return fetch_error_json(&url, e),
                    Ok(None) => None,
                    Err(_) => return fetch_error_json(&url, "timed out"),
                },
                _ = token.cancelled() => return fetch_cancelled_json(&url),
            };
            let Some(chunk) = chunk else { break };
            if let Err(msg) = push_capped(&mut bytes, &chunk) {
                return fetch_error_json(&url, msg);
            }
        }
        return crate::extract::pack_http_envelope(status, final_url, hdrs, bytes);
    }
}
