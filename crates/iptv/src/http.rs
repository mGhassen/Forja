//! Shared reqwest builder for portal / stream HTTP.

use std::time::Duration;

use utils::dns::portal_client_builder;

/// Build a portal/stream HTTP client.
///
/// Real IPv6 addresses are usable. A DNS64 `64:ff9b::/96` translation is
/// dropped when a real IPv4 or IPv6 address exists, and an IPv4 lookup is
/// still tried when DNS returns only that translation. The socket is not
/// bound to IPv4, so a real AAAA can connect.
pub fn client(timeout: Duration) -> Result<reqwest::Client, String> {
    builder(timeout, false)?.build().map_err(|e| e.to_string())
}

/// Same as [client] with a cookie jar (Stalker Mag sessions).
pub fn client_with_cookies(timeout: Duration) -> Result<reqwest::Client, String> {
    builder(timeout, true)?.build().map_err(|e| e.to_string())
}

fn builder(timeout: Duration, cookies: bool) -> Result<reqwest::ClientBuilder, String> {
    let mut b = portal_client_builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(8));
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
    fn builds_client() {
        assert!(client(Duration::from_secs(5)).is_ok());
        assert!(client_with_cookies(Duration::from_secs(5)).is_ok());
    }

    #[tokio::test]
    async fn lookup_ipv4_literal() {
        let addrs = resolve_host("127.0.0.1").await.unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv4());
    }

    #[tokio::test]
    async fn lookup_keeps_ipv6_literal() {
        let addrs = resolve_host("::1").await.unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv6());
    }

    #[tokio::test]
    async fn lookup_localhost() {
        let addrs = resolve_host("localhost").await.expect("localhost");
        assert!(!addrs.is_empty());
    }
}
