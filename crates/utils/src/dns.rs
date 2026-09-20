//! System DNS with Cloudflare DoH (`1.1.1.1`) fallback.
//!
//! Phone hotspots often break Android Private DNS / the carrier DNS forwarder
//! while raw IP connectivity still works. Pack install already does this in
//! Dart (`PackHttp`); engine / IPTV / catalog HTTP need the same path.

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::sync::{Arc, LazyLock};
use std::time::Duration;

use reqwest::dns::{Addrs, Name, Resolve, Resolving};
use serde::Deserialize;

/// Cap system lookup — Android TV / hotspot can hang forever on getaddrinfo.
pub const SYSTEM_DNS_TIMEOUT: Duration = Duration::from_secs(5);

/// Cloudflare DNS-over-HTTPS JSON API — literal IP so we do not need recursive DNS.
pub const DOH_URL: &str = "https://1.1.1.1/dns-query";

/// reqwest resolver: system DNS first, then DoH.
#[derive(Debug, Clone, Copy)]
pub struct DohFallbackResolver {
    /// When true, only A records (AF_INET) — IPTV Windows DNS64 (issue 261).
    pub ipv4_only: bool,
}

impl DohFallbackResolver {
    pub const fn dual_stack() -> Self {
        Self { ipv4_only: false }
    }

    pub const fn ipv4_only() -> Self {
        Self { ipv4_only: true }
    }
}

impl Default for DohFallbackResolver {
    fn default() -> Self {
        Self::dual_stack()
    }
}

impl Resolve for DohFallbackResolver {
    fn resolve(&self, name: Name) -> Resolving {
        let host = name.as_str().trim_end_matches('.').to_owned();
        let ipv4_only = self.ipv4_only;
        Box::pin(async move {
            let addrs = resolve_host(&host, ipv4_only)
                .await
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
            Ok(Box::new(addrs.into_iter()) as Addrs)
        })
    }
}

/// Resolve `host` via system DNS (timed), then Cloudflare DoH.
pub async fn resolve_host(
    host: &str,
    ipv4_only: bool,
) -> Result<Vec<SocketAddr>, std::io::Error> {
    let host = host.trim().trim_end_matches('.');
    if host.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "empty host",
        ));
    }

    if let Ok(ip) = host.parse::<IpAddr>() {
        return match (ip, ipv4_only) {
            (IpAddr::V4(v4), _) => Ok(vec![SocketAddr::new(IpAddr::V4(v4), 0)]),
            (IpAddr::V6(_), true) => Err(std::io::Error::new(
                std::io::ErrorKind::AddrNotAvailable,
                "IPv6 literal rejected (IPv4-only resolver)",
            )),
            (IpAddr::V6(v6), false) => Ok(vec![SocketAddr::new(IpAddr::V6(v6), 0)]),
        };
    }

    match system_lookup(host, ipv4_only).await {
        Ok(addrs) if !addrs.is_empty() => return Ok(addrs),
        Ok(_) => {}
        Err(_) => {}
    }

    let via_doh = lookup_doh(host, ipv4_only).await?;
    if via_doh.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::AddrNotAvailable,
            format!("no addresses for {host} (system DNS + DoH)"),
        ));
    }
    Ok(via_doh)
}

async fn system_lookup(host: &str, ipv4_only: bool) -> Result<Vec<SocketAddr>, std::io::Error> {
    let host = host.to_owned();
    let fut = tokio::task::spawn_blocking(move || {
        if ipv4_only {
            lookup_ipv4_blocking(&host)
        } else {
            lookup_unspec_blocking(&host)
        }
    });
    match tokio::time::timeout(SYSTEM_DNS_TIMEOUT, fut).await {
        Ok(Ok(r)) => r,
        Ok(Err(e)) => Err(std::io::Error::other(e)),
        Err(_) => Err(std::io::Error::new(
            std::io::ErrorKind::TimedOut,
            "system DNS timed out",
        )),
    }
}

fn lookup_unspec_blocking(host: &str) -> Result<Vec<SocketAddr>, std::io::Error> {
    use std::net::ToSocketAddrs;
    let addrs: Vec<SocketAddr> = (host, 0u16)
        .to_socket_addrs()?
        .map(|a| SocketAddr::new(a.ip(), 0))
        .collect();
    if addrs.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::AddrNotAvailable,
            format!("no addresses for {host}"),
        ));
    }
    Ok(prefer_ipv4(addrs))
}

fn prefer_ipv4(mut addrs: Vec<SocketAddr>) -> Vec<SocketAddr> {
    addrs.sort_by_key(|a| if a.is_ipv4() { 0 } else { 1 });
    addrs
}

fn lookup_ipv4_blocking(host: &str) -> Result<Vec<SocketAddr>, std::io::Error> {
    use std::ffi::CString;

    let c_host = CString::new(host).map_err(|e| {
        std::io::Error::new(std::io::ErrorKind::InvalidInput, e)
    })?;

    let mut hints: libc::addrinfo = unsafe { std::mem::zeroed() };
    hints.ai_family = libc::AF_INET;
    hints.ai_socktype = libc::SOCK_STREAM;

    let mut res: *mut libc::addrinfo = std::ptr::null_mut();
    let rc = unsafe {
        libc::getaddrinfo(c_host.as_ptr(), std::ptr::null(), &hints, &mut res)
    };
    if rc != 0 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("getaddrinfo AF_INET failed ({rc})"),
        ));
    }

    let mut out = Vec::new();
    let mut cur = res;
    while !cur.is_null() {
        unsafe {
            let ai = &*cur;
            if ai.ai_family == libc::AF_INET && !ai.ai_addr.is_null() {
                let sin = &*(ai.ai_addr as *const libc::sockaddr_in);
                let ip = Ipv4Addr::from(u32::from_be(sin.sin_addr.s_addr));
                out.push(SocketAddr::new(IpAddr::V4(ip), 0));
            }
            cur = ai.ai_next;
        }
    }
    unsafe { libc::freeaddrinfo(res) };

    if out.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::AddrNotAvailable,
            format!("no IPv4 addresses for {host}"),
        ));
    }
    Ok(out)
}

/// DoH client hits `1.1.1.1` by IP — must not use [DohFallbackResolver] (recursion).
static DOH_CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .timeout(Duration::from_secs(8))
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("DoH http client")
});

async fn lookup_doh(host: &str, ipv4_only: bool) -> Result<Vec<SocketAddr>, std::io::Error> {
    let a = doh_query(host, "A").await.unwrap_or_default();
    if !a.is_empty() {
        return Ok(a);
    }
    if ipv4_only {
        return Ok(Vec::new());
    }
    Ok(doh_query(host, "AAAA").await.unwrap_or_default())
}

async fn doh_query(host: &str, rtype: &str) -> Result<Vec<SocketAddr>, std::io::Error> {
    let uri = reqwest::Url::parse_with_params(
        DOH_URL,
        &[("name", host), ("type", rtype)],
    )
    .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidInput, e))?;

    let resp = DOH_CLIENT
        .get(uri)
        .header("Accept", "application/dns-json")
        .send()
        .await
        .map_err(|e| std::io::Error::other(e))?;

    if !resp.status().is_success() {
        return Err(std::io::Error::other(format!(
            "DoH HTTP {}",
            resp.status()
        )));
    }

    let body = resp
        .text()
        .await
        .map_err(|e| std::io::Error::other(e))?;
    Ok(parse_doh_answers(&body, rtype))
}

#[derive(Debug, Deserialize)]
struct DohResponse {
    #[serde(default, rename = "Answer")]
    answer: Vec<DohAnswer>,
}

#[derive(Debug, Deserialize)]
struct DohAnswer {
    #[serde(default)]
    data: String,
    #[serde(default, rename = "type")]
    r#type: i32,
}

/// Parse Cloudflare/Google `application/dns-json` answers (A=1, AAAA=28).
pub fn parse_doh_answers(body: &str, rtype: &str) -> Vec<SocketAddr> {
    let Ok(decoded) = serde_json::from_str::<DohResponse>(body) else {
        return Vec::new();
    };
    let want_a = rtype.eq_ignore_ascii_case("A");
    let want_type = if want_a { 1 } else { 28 };
    let mut out = Vec::new();
    for ans in decoded.answer {
        if ans.r#type != want_type {
            continue;
        }
        let data = ans.data.trim();
        if data.is_empty() {
            continue;
        }
        if want_a {
            if let Ok(v4) = data.parse::<Ipv4Addr>() {
                out.push(SocketAddr::new(IpAddr::V4(v4), 0));
            }
        } else if let Ok(v6) = data.parse::<Ipv6Addr>() {
            out.push(SocketAddr::new(IpAddr::V6(v6), 0));
        }
    }
    out
}

/// Shared reqwest builder with DoH-fallback DNS (dual-stack, IPv4 preferred).
pub fn client_builder() -> reqwest::ClientBuilder {
    reqwest::Client::builder().dns_resolver(Arc::new(DohFallbackResolver::dual_stack()))
}

/// Same as [client_builder] but AF_INET / A-record only (IPTV).
pub fn ipv4_client_builder() -> reqwest::ClientBuilder {
    reqwest::Client::builder().dns_resolver(Arc::new(DohFallbackResolver::ipv4_only()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_a_records() {
        let body = r#"{
          "Status": 0,
          "Answer": [
            {"name":"example.com.","type":1,"TTL":60,"data":"93.184.216.34"},
            {"name":"example.com.","type":5,"TTL":60,"data":"ignored.cname."}
          ]
        }"#;
        let addrs = parse_doh_answers(body, "A");
        assert_eq!(addrs.len(), 1);
        assert_eq!(addrs[0].ip(), IpAddr::V4(Ipv4Addr::new(93, 184, 216, 34)));
    }

    #[test]
    fn parse_aaaa_records() {
        let body = r#"{
          "Answer": [
            {"name":"example.com.","type":28,"TTL":60,"data":"2606:2800:220:1:248:1893:25c8:1946"}
          ]
        }"#;
        let addrs = parse_doh_answers(body, "AAAA");
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv6());
    }

    #[tokio::test]
    async fn literal_ipv4() {
        let addrs = resolve_host("127.0.0.1", true).await.unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv4());
    }

    #[tokio::test]
    async fn rejects_ipv6_when_ipv4_only() {
        assert!(resolve_host("::1", true).await.is_err());
    }

    #[tokio::test]
    async fn localhost_system_or_doh() {
        let addrs = resolve_host("localhost", true).await.expect("localhost");
        assert!(addrs.iter().all(|a| a.is_ipv4()));
        assert!(!addrs.is_empty());
    }
}
