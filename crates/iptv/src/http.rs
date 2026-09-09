//! Shared reqwest builder for portal / stream HTTP.

use std::net::{IpAddr, Ipv4Addr};
use std::time::Duration;

/// Build a portal/stream HTTP client.
///
/// Binds outbound sockets to IPv4. DynDNS / ISP DNS64 often synthesizes AAAA
/// under `64:ff9b::/96`. Windows `getaddrinfo` prefers those; without a NAT64
/// gateway the connect hangs or fails while macOS (A-records only) and Android
/// TV still reach the same host over IPv4 — false "Could not reach portal".
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
        .local_address(IpAddr::V4(Ipv4Addr::UNSPECIFIED));
    if cookies {
        b = b.cookie_store(true);
    }
    Ok(b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_ipv4_client() {
        assert!(client(Duration::from_secs(5)).is_ok());
        assert!(client_with_cookies(Duration::from_secs(5)).is_ok());
    }
}
