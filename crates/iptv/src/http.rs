//! Shared reqwest builder for portal / stream HTTP.

use std::net::IpAddr;
use std::net::Ipv4Addr;
use std::sync::Arc;
use std::time::Duration;

use utils::dns::DohFallbackResolver;

/// Build a portal/stream HTTP client.
///
/// Forces **AF_INET** DNS (real A records) and binds sockets to IPv4.
///
/// DynDNS / ISP DNS64 often synthesizes AAAA under `64:ff9b::/96`. Windows
/// `getaddrinfo(AF_UNSPEC)` prefers those; without NAT64 connect fails while
/// macOS/ATV still reach the host over IPv4.
///
/// System DNS first; Cloudflare DoH (`1.1.1.1`) when lookup fails (hotspot /
/// Private DNS breakage — same path as Dart `PackHttp`).
///
/// `local_address(0.0.0.0)` alone is not enough: hyper then **filters** the
/// AF_UNSPEC result to IPv4, and when DNS returns AAAA-only the address list
/// is empty → false "Could not reach portal". AF_INET lookup asks for A
/// records explicitly.
pub fn client(timeout: Duration) -> Result<reqwest::Client, String> {
    builder(timeout, false)?.build().map_err(|e| e.to_string())
}

/// Same as [client] with a cookie jar (Stalker Mag sessions).
pub fn client_with_cookies(timeout: Duration) -> Result<reqwest::Client, String> {
    builder(timeout, true)?.build().map_err(|e| e.to_string())
}

fn builder(timeout: Duration, cookies: bool) -> Result<reqwest::ClientBuilder, String> {
    let mut b = reqwest::Client::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(8))
        .local_address(IpAddr::V4(Ipv4Addr::UNSPECIFIED))
        .dns_resolver(Arc::new(DohFallbackResolver::ipv4_only()));
    if cookies {
        b = b.cookie_store(true);
    }
    Ok(b)
}

#[cfg(test)]
mod tests {
    use super::*;
    use utils::dns::resolve_host;

    #[test]
    fn builds_ipv4_client() {
        assert!(client(Duration::from_secs(5)).is_ok());
        assert!(client_with_cookies(Duration::from_secs(5)).is_ok());
    }

    #[tokio::test]
    async fn lookup_ipv4_literal() {
        let addrs = resolve_host("127.0.0.1", true).await.unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv4());
    }

    #[tokio::test]
    async fn lookup_rejects_ipv6_literal() {
        assert!(resolve_host("::1", true).await.is_err());
    }

    #[tokio::test]
    async fn lookup_ipv4_localhost() {
        let addrs = resolve_host("localhost", true)
            .await
            .expect("localhost A record");
        assert!(addrs.iter().all(|a| a.is_ipv4()));
        assert!(!addrs.is_empty());
    }
}
