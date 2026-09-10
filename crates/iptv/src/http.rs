//! Shared reqwest builder for portal / stream HTTP.

use std::ffi::CString;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::sync::Arc;
use std::time::Duration;

use reqwest::dns::{Addrs, Name, Resolve, Resolving};

/// Build a portal/stream HTTP client.
///
/// Forces **AF_INET** DNS (real A records) and binds sockets to IPv4.
///
/// DynDNS / ISP DNS64 often synthesizes AAAA under `64:ff9b::/96`. Windows
/// `getaddrinfo(AF_UNSPEC)` prefers those; without NAT64 connect fails while
/// macOS/ATV still reach the host over IPv4.
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
        .dns_resolver(Arc::new(Ipv4Dns));
    if cookies {
        b = b.cookie_store(true);
    }
    Ok(b)
}

/// Resolver that only returns IPv4 addresses (AF_INET `getaddrinfo`).
struct Ipv4Dns;

impl Resolve for Ipv4Dns {
    fn resolve(&self, name: Name) -> Resolving {
        let host = name.as_str().to_owned();
        Box::pin(async move {
            let addrs = tokio::task::spawn_blocking(move || lookup_ipv4(&host))
                .await
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
            Ok(Box::new(addrs.into_iter()) as Addrs)
        })
    }
}

fn lookup_ipv4(host: &str) -> std::io::Result<Vec<SocketAddr>> {
    if let Ok(ip) = host.parse::<IpAddr>() {
        return match ip {
            IpAddr::V4(v4) => Ok(vec![SocketAddr::new(IpAddr::V4(v4), 0)]),
            IpAddr::V6(_) => Err(std::io::Error::new(
                std::io::ErrorKind::AddrNotAvailable,
                "IPv6 literal rejected (portal HTTP is IPv4-only)",
            )),
        };
    }

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
                // SAFETY: AF_INET ⇒ sockaddr_in.
                let sin = &*(ai.ai_addr as *const libc::sockaddr_in);
                let ip = Ipv4Addr::from(u32::from_be(sin.sin_addr.s_addr));
                // Port 0: reqwest/hyper replaces with the URL scheme port.
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_ipv4_client() {
        assert!(client(Duration::from_secs(5)).is_ok());
        assert!(client_with_cookies(Duration::from_secs(5)).is_ok());
    }

    #[test]
    fn lookup_ipv4_literal() {
        let addrs = lookup_ipv4("127.0.0.1").unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv4());
    }

    #[test]
    fn lookup_rejects_ipv6_literal() {
        assert!(lookup_ipv4("::1").is_err());
    }

    #[test]
    fn lookup_ipv4_localhost() {
        let addrs = lookup_ipv4("localhost").expect("localhost A record");
        assert!(addrs.iter().all(|a| a.is_ipv4()));
        assert!(!addrs.is_empty());
    }
}
