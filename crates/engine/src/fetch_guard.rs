//! Outbound guard for plugin `fetch` / `__engineChromeFetch`.
//!
//! Pack JS runs untrusted code against the user's network. Every hop (the first
//! request and each redirect) is resolved here first; destinations that land on
//! loopback, link-local, RFC1918, CGNAT, IPv6 ULA or other non-public ranges are
//! refused unless the job carries `allow_local_fetch: true`. Resolved addresses
//! are pinned onto the HTTP client so the connection cannot rebind elsewhere.
//! Redirects are followed by hand (`Policy::none()` on the client) so the check
//! runs on each hop, and response bodies stop at [`MAX_RESPONSE_BYTES`].

use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::time::Duration;

use serde_json::{json, Value};
use url::{Host, Url};

use utils::engine_cancel::cancellation_token;

/// Whole-request budget (connect + every redirect hop + body read).
pub const FETCH_TIMEOUT: Duration = Duration::from_secs(25);
/// Redirect hops followed before `too many redirects`.
pub const MAX_REDIRECTS: usize = 8;
/// Largest body a plugin fetch may buffer. Scrapers read HTML / JSON / small
/// playlists; media bytes never flow through `fetch`.
pub const MAX_RESPONSE_BYTES: usize = 16 * 1024 * 1024;

/// Request headers a plugin may not override. `Host` would desync the SNI /
/// SSRF check from the socket; framing headers are owned by the HTTP client.
const FORBIDDEN_REQUEST_HEADERS: [&str; 3] = ["host", "content-length", "transfer-encoding"];

/// Dropped when a redirect changes host (mirrors reqwest's redirect policy).
const SENSITIVE_REDIRECT_HEADERS: [&str; 5] = [
    "authorization",
    "cookie",
    "cookie2",
    "proxy-authorization",
    "www-authenticate",
];

const BLOCKED_LOCAL_MESSAGE: &str =
    "blocked: destination resolves to a local or private network address";

pub fn fetch_error_json(url: &str, msg: impl ToString) -> String {
    json!({
        "ok": false, "status": 0, "statusText": msg.to_string(),
        "url": url, "body": "", "headers": {}
    })
    .to_string()
}

pub fn fetch_cancelled_json(url: &str) -> String {
    fetch_error_json(url, "cancelled")
}

/// True for every address a plugin must not reach without an explicit opt-in:
/// unspecified, loopback, link-local, RFC1918, CGNAT 100.64/10, broadcast,
/// multicast, 0.0.0.0/8, IPv6 ULA, and IPv4 embedded in IPv6 (mapped / NAT64).
pub fn is_local_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => is_local_v4(v4),
        IpAddr::V6(v6) => is_local_v6(v6),
    }
}

fn is_local_v4(ip: Ipv4Addr) -> bool {
    let o = ip.octets();
    ip.is_unspecified()
        || ip.is_loopback()
        || ip.is_link_local()
        || ip.is_private()
        || ip.is_broadcast()
        || ip.is_multicast()
        || ip.is_documentation()
        // 0.0.0.0/8 "this network" — routes to the local host on Linux.
        || o[0] == 0
        // CGNAT 100.64.0.0/10.
        || (o[0] == 100 && (64..=127).contains(&o[1]))
        // 192.0.0.0/24 IETF protocol assignments (incl. 192.0.0.192 / 10).
        || (o[0] == 192 && o[1] == 0 && o[2] == 0)
}

fn is_local_v6(ip: Ipv6Addr) -> bool {
    if let Some(v4) = ip.to_ipv4_mapped() {
        return is_local_v4(v4);
    }
    let seg = ip.segments();
    // NAT64 well-known prefix 64:ff9b::/96 embeds an IPv4 address.
    if seg[0] == 0x64 && seg[1] == 0xff9b && seg[2..6] == [0, 0, 0, 0] {
        let v4 = Ipv4Addr::new(
            (seg[6] >> 8) as u8,
            (seg[6] & 0xff) as u8,
            (seg[7] >> 8) as u8,
            (seg[7] & 0xff) as u8,
        );
        return is_local_v4(v4);
    }
    // Deprecated ::a.b.c.d compat form.
    if seg[..6] == [0, 0, 0, 0, 0, 0] && !(seg[6] == 0 && seg[7] <= 1) {
        let v4 = Ipv4Addr::new(
            (seg[6] >> 8) as u8,
            (seg[6] & 0xff) as u8,
            (seg[7] >> 8) as u8,
            (seg[7] & 0xff) as u8,
        );
        return is_local_v4(v4);
    }
    ip.is_unspecified()
        || ip.is_loopback()
        || ip.is_multicast()
        // fe80::/10 link-local.
        || (seg[0] & 0xffc0) == 0xfe80
        // fc00::/7 unique local.
        || (seg[0] & 0xfe00) == 0xfc00
        // 2001:db8::/32 documentation.
        || (seg[0] == 0x2001 && seg[1] == 0x0db8)
}

/// Host names that always mean "this machine" regardless of DNS.
pub fn is_local_host_literal(host: &str) -> bool {
    let h = host.trim_end_matches('.').to_ascii_lowercase();
    h == "localhost" || h.ends_with(".localhost")
}

/// Drop request headers a plugin may not set (case-insensitive).
pub fn strip_forbidden_headers(headers: &mut HashMap<String, String>) {
    headers.retain(|k, _| {
        let lower = k.trim().to_ascii_lowercase();
        !FORBIDDEN_REQUEST_HEADERS.contains(&lower.as_str())
    });
}

/// Drop credentials before following a redirect to a different host.
pub fn drop_sensitive_headers(headers: &mut HashMap<String, String>) {
    headers.retain(|k, _| {
        let lower = k.trim().to_ascii_lowercase();
        !SENSITIVE_REDIRECT_HEADERS.contains(&lower.as_str())
    });
}

/// Host or port differs — the redirect leaves the origin.
pub fn is_cross_host(from: &Url, to: &Url) -> bool {
    from.host_str().map(str::to_ascii_lowercase) != to.host_str().map(str::to_ascii_lowercase)
        || from.port_or_known_default() != to.port_or_known_default()
}

/// Where a redirect response sends us, and with which method.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RedirectHop {
    pub url: Url,
    pub method: String,
    /// 307 / 308 replay the body; 301 / 302 / 303 switch to GET without it.
    pub keep_body: bool,
}

/// Browser-style redirect rules: 301/302/303 → GET (HEAD stays HEAD),
/// 307/308 keep method and body. `None` when the response is not a redirect
/// or has no usable `Location`.
pub fn next_redirect_hop(
    status: u16,
    location: Option<&str>,
    current: &Url,
    method: &str,
) -> Option<RedirectHop> {
    let loc = location?.trim();
    if loc.is_empty() {
        return None;
    }
    let (method, keep_body) = match status {
        301..=303 => {
            if method.eq_ignore_ascii_case("HEAD") {
                ("HEAD".to_string(), false)
            } else {
                ("GET".to_string(), false)
            }
        }
        307 | 308 => (method.to_ascii_uppercase(), true),
        _ => return None,
    };
    let url = current.join(loc).ok()?;
    Some(RedirectHop {
        url,
        method,
        keep_body,
    })
}

/// Resolve `url`'s host and refuse local / private destinations unless
/// `allow_local`. Returns the host string reqwest will see plus the pinned
/// socket addresses (empty for IP literals — nothing to pin).
pub async fn resolve_checked(
    url: &Url,
    allow_local: bool,
) -> Result<(String, Vec<SocketAddr>), String> {
    match url.scheme() {
        "http" | "https" => {}
        other => return Err(format!("blocked: unsupported scheme {other}")),
    }
    let port = url
        .port_or_known_default()
        .ok_or_else(|| "blocked: no port".to_string())?;
    let host = url.host().ok_or_else(|| "blocked: no host".to_string())?;
    match host {
        Host::Ipv4(ip) => {
            if !allow_local && is_local_ip(IpAddr::V4(ip)) {
                return Err(BLOCKED_LOCAL_MESSAGE.into());
            }
            Ok((ip.to_string(), vec![]))
        }
        Host::Ipv6(ip) => {
            if !allow_local && is_local_ip(IpAddr::V6(ip)) {
                return Err(BLOCKED_LOCAL_MESSAGE.into());
            }
            Ok((ip.to_string(), vec![]))
        }
        Host::Domain(name) => {
            let name = name.to_string();
            if !allow_local && is_local_host_literal(&name) {
                return Err(BLOCKED_LOCAL_MESSAGE.into());
            }
            let addrs: Vec<SocketAddr> = tokio::net::lookup_host((name.as_str(), port))
                .await
                .map_err(|e| format!("dns: {e}"))?
                .collect();
            if addrs.is_empty() {
                return Err("dns: no addresses".into());
            }
            // Any private answer blocks the hop — a public+private mix is the
            // classic rebinding trick.
            if !allow_local && addrs.iter().any(|a| is_local_ip(a.ip())) {
                return Err(BLOCKED_LOCAL_MESSAGE.into());
            }
            Ok((name, addrs))
        }
    }
}

/// Whole-chain deadline for one plugin fetch (tokio clock, for `timeout_at`).
pub fn fetch_deadline() -> tokio::time::Instant {
    tokio::time::Instant::now() + FETCH_TIMEOUT
}

/// Reject early when the server announces a body above the cap.
pub fn content_length_too_large(content_length: Option<u64>) -> bool {
    content_length.is_some_and(|len| len > MAX_RESPONSE_BYTES as u64)
}

/// Accumulate a chunk under the cap. `Err` once the body would exceed it.
pub fn push_capped(buf: &mut Vec<u8>, chunk: &[u8]) -> Result<(), String> {
    if buf.len().saturating_add(chunk.len()) > MAX_RESPONSE_BYTES {
        return Err(format!(
            "response too large (over {} bytes)",
            MAX_RESPONSE_BYTES
        ));
    }
    buf.extend_from_slice(chunk);
    Ok(())
}

fn headers_to_json(headers: &reqwest::header::HeaderMap) -> serde_json::Map<String, Value> {
    let mut hdrs = serde_json::Map::new();
    for (k, v) in headers.iter() {
        if let Ok(s) = v.to_str() {
            hdrs.insert(k.to_string(), Value::String(s.to_string()));
        }
    }
    hdrs
}

/// Plain reqwest (rustls) fetch with the full guard. Returns the JSON envelope
/// `HOST_JS` wraps into a `Response`.
pub async fn guarded_fetch(
    url: String,
    method: String,
    mut headers: HashMap<String, String>,
    body: String,
    allow_local: bool,
) -> String {
    let token = cancellation_token();
    if token.is_cancelled() {
        return fetch_cancelled_json(&url);
    }
    let deadline = fetch_deadline();
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
        let mut builder = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(FETCH_TIMEOUT);
        if !addrs.is_empty() {
            builder = builder.resolve_to_addrs(&host, &addrs);
        }
        let client = match builder.build() {
            Ok(c) => c,
            Err(e) => return fetch_error_json(&url, e),
        };
        let method =
            reqwest::Method::from_bytes(method_up.as_bytes()).unwrap_or(reqwest::Method::GET);
        let mut req = client.request(method, current.clone());
        for (k, v) in &headers {
            req = req.header(k, v);
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
            .get(reqwest::header::LOCATION)
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

        let final_url = resp.url().to_string();
        let hdrs = headers_to_json(resp.headers());
        // HEAD must not buffer a redirected video body (HubCloud 10Gbps → googleusercontent).
        if method_up == "HEAD" {
            return crate::extract::pack_http_envelope(status, final_url, hdrs, Vec::new());
        }
        if content_length_too_large(resp.content_length()) {
            return fetch_error_json(
                &url,
                format!("response too large (over {} bytes)", MAX_RESPONSE_BYTES),
            );
        }
        let mut resp = resp;
        let mut bytes: Vec<u8> = Vec::new();
        loop {
            let chunk = tokio::select! {
                c = tokio::time::timeout_at(deadline, resp.chunk()) => match c {
                    Ok(Ok(c)) => c,
                    Ok(Err(e)) => return fetch_error_json(&url, e),
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

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    fn ip(s: &str) -> IpAddr {
        s.parse().unwrap()
    }

    #[test]
    fn classifier_blocks_local_ranges() {
        for s in [
            "127.0.0.1",
            "127.8.8.8",
            "0.0.0.0",
            "0.1.2.3",
            "10.0.0.1",
            "172.16.0.1",
            "172.31.255.254",
            "192.168.1.1",
            "169.254.169.254",
            "100.64.0.1",
            "100.127.255.255",
            "192.0.0.192",
            "224.0.0.1",
            "255.255.255.255",
            "::1",
            "::",
            "fe80::1",
            "fc00::1",
            "fd12:3456::1",
            "ff02::1",
            "::ffff:127.0.0.1",
            "::ffff:10.1.2.3",
            "64:ff9b::7f00:1",
            "64:ff9b::a00:1",
        ] {
            assert!(is_local_ip(ip(s)), "{s} should be local");
        }
    }

    #[test]
    fn classifier_allows_public_ranges() {
        for s in [
            "1.1.1.1",
            "8.8.8.8",
            "100.63.255.255",
            "100.128.0.1",
            "172.15.255.255",
            "172.32.0.1",
            "192.0.1.1",
            "2606:4700:4700::1111",
            "2a00:1450:4001:80e::200e",
            "::ffff:8.8.8.8",
            "64:ff9b::808:808",
        ] {
            assert!(!is_local_ip(ip(s)), "{s} should be public");
        }
    }

    #[test]
    fn localhost_literals() {
        assert!(is_local_host_literal("localhost"));
        assert!(is_local_host_literal("LOCALHOST."));
        assert!(is_local_host_literal("api.localhost"));
        assert!(!is_local_host_literal("localhost.example.com"));
        assert!(!is_local_host_literal("example.com"));
    }

    #[test]
    fn strips_host_and_framing_headers_case_insensitive() {
        let mut h: HashMap<String, String> = [
            ("Host", "evil.internal"),
            ("content-length", "5"),
            ("Transfer-Encoding", "chunked"),
            ("Referer", "https://ref/"),
            ("X-Custom", "1"),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect();
        strip_forbidden_headers(&mut h);
        assert_eq!(h.len(), 2);
        assert!(h.contains_key("Referer"));
        assert!(h.contains_key("X-Custom"));
    }

    #[test]
    fn drops_credentials_only() {
        let mut h: HashMap<String, String> = [
            ("Authorization", "Bearer x"),
            ("Cookie", "a=b"),
            ("Referer", "https://ref/"),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect();
        drop_sensitive_headers(&mut h);
        assert_eq!(h.len(), 1);
        assert!(h.contains_key("Referer"));
    }

    #[test]
    fn redirect_rules() {
        let cur = Url::parse("https://a.example/x/y").unwrap();
        let hop = next_redirect_hop(302, Some("/z"), &cur, "POST").unwrap();
        assert_eq!(hop.url.as_str(), "https://a.example/z");
        assert_eq!(hop.method, "GET");
        assert!(!hop.keep_body);

        let hop = next_redirect_hop(307, Some("https://b.example/"), &cur, "post").unwrap();
        assert_eq!(hop.method, "POST");
        assert!(hop.keep_body);

        let hop = next_redirect_hop(301, Some("/h"), &cur, "HEAD").unwrap();
        assert_eq!(hop.method, "HEAD");

        assert!(next_redirect_hop(200, Some("/z"), &cur, "GET").is_none());
        assert!(next_redirect_hop(302, None, &cur, "GET").is_none());
        assert!(next_redirect_hop(302, Some("   "), &cur, "GET").is_none());
    }

    #[test]
    fn cross_host_detection() {
        let a = Url::parse("https://a.example/").unwrap();
        let a2 = Url::parse("https://A.example:443/p").unwrap();
        let b = Url::parse("https://b.example/").unwrap();
        let a_http = Url::parse("http://a.example/").unwrap();
        assert!(!is_cross_host(&a, &a2));
        assert!(is_cross_host(&a, &b));
        assert!(is_cross_host(&a, &a_http));
    }

    #[test]
    fn body_cap_math() {
        let mut buf = Vec::new();
        assert!(push_capped(&mut buf, &vec![0u8; MAX_RESPONSE_BYTES]).is_ok());
        assert!(push_capped(&mut buf, &[0u8]).is_err());
        assert!(content_length_too_large(Some(
            MAX_RESPONSE_BYTES as u64 + 1
        )));
        assert!(!content_length_too_large(Some(MAX_RESPONSE_BYTES as u64)));
        assert!(!content_length_too_large(None));
    }

    #[tokio::test]
    async fn resolve_checked_refuses_loopback_literal_and_localhost() {
        let u = Url::parse("http://127.0.0.1:8080/").unwrap();
        assert!(resolve_checked(&u, false).await.is_err());
        assert!(resolve_checked(&u, true).await.is_ok());
        let u = Url::parse("http://localhost/").unwrap();
        assert!(resolve_checked(&u, false).await.is_err());
        let u = Url::parse("http://[::1]/").unwrap();
        assert!(resolve_checked(&u, false).await.is_err());
        let u = Url::parse("file:///etc/passwd").unwrap();
        assert!(resolve_checked(&u, false).await.is_err());
    }

    /// Minimal HTTP/1.1 server on loopback: answers every request with
    /// `status`, `extra_headers`, and `body_len` zero bytes (or a Location hop).
    async fn serve_once(
        listener: tokio::net::TcpListener,
        status: u16,
        extra_headers: Vec<String>,
        body_len: usize,
    ) {
        let (mut sock, _) = listener.accept().await.unwrap();
        let mut buf = [0u8; 4096];
        let _ = sock.read(&mut buf).await;
        let mut head = format!("HTTP/1.1 {status} X\r\nContent-Length: {body_len}\r\n");
        for h in extra_headers {
            head.push_str(&h);
            head.push_str("\r\n");
        }
        head.push_str("Connection: close\r\n\r\n");
        sock.write_all(head.as_bytes()).await.unwrap();
        let chunk = vec![b'a'; 64 * 1024];
        let mut left = body_len;
        while left > 0 {
            let n = left.min(chunk.len());
            if sock.write_all(&chunk[..n]).await.is_err() {
                break;
            }
            left -= n;
        }
        let _ = sock.shutdown().await;
    }

    #[tokio::test]
    async fn guarded_fetch_blocks_loopback_without_opt_in() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let url = format!("http://127.0.0.1:{port}/");
        let raw = guarded_fetch(url, "GET".into(), HashMap::new(), String::new(), false).await;
        let v: Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(v["ok"], false);
        assert_eq!(v["status"], 0);
        assert!(
            v["statusText"].as_str().unwrap().starts_with("blocked:"),
            "{raw}"
        );
    }

    #[tokio::test]
    async fn guarded_fetch_opt_in_reads_small_body() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let server = tokio::spawn(serve_once(
            listener,
            200,
            vec!["Content-Type: text/plain".into()],
            5,
        ));
        let url = format!("http://127.0.0.1:{port}/ok");
        let raw = guarded_fetch(url, "GET".into(), HashMap::new(), String::new(), true).await;
        let v: Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(v["ok"], true, "{raw}");
        assert_eq!(v["status"], 200);
        assert_eq!(v["body"], "aaaaa");
        server.await.unwrap();
    }

    #[tokio::test]
    async fn guarded_fetch_aborts_oversized_body() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        // Announce a body over the cap — the client must stop without buffering it.
        let server = tokio::spawn(serve_once(listener, 200, vec![], MAX_RESPONSE_BYTES + 1));
        let url = format!("http://127.0.0.1:{port}/big");
        let raw = guarded_fetch(url, "GET".into(), HashMap::new(), String::new(), true).await;
        let v: Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(v["ok"], false);
        assert!(
            v["statusText"]
                .as_str()
                .unwrap()
                .contains("response too large"),
            "{raw}"
        );
        server.abort();
    }

    #[tokio::test]
    async fn guarded_fetch_redirect_hop_is_rechecked() {
        // Offline we cannot mix a public first hop with a private second one,
        // so this exercises the per-hop loop through its redirect ceiling.
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let server = tokio::spawn(async move {
            for _ in 0..=MAX_REDIRECTS {
                let (mut sock, _) = listener.accept().await.unwrap();
                let mut buf = [0u8; 4096];
                let _ = sock.read(&mut buf).await;
                let head = format!(
                    "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:{port}/again\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                );
                let _ = sock.write_all(head.as_bytes()).await;
                let _ = sock.shutdown().await;
            }
        });
        let url = format!("http://127.0.0.1:{port}/start");
        let raw = guarded_fetch(url, "GET".into(), HashMap::new(), String::new(), true).await;
        let v: Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(v["ok"], false);
        assert_eq!(v["statusText"], "too many redirects", "{raw}");
        server.abort();
    }
}
