//! System DNS for IPTV portals.
//!
//! Portals ask for A records only (`AF_INET`). Windows DNS64 returns AAAA
//! under `AF_UNSPEC`, and an IPv4 socket then has nothing to connect to.
//! Other HTTP clients use reqwest's default resolver.

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::sync::Arc;

use reqwest::dns::{Addrs, Name, Resolve, Resolving};

struct Ipv4Resolver;

impl Resolve for Ipv4Resolver {
    fn resolve(&self, name: Name) -> Resolving {
        let host = name.as_str().trim_end_matches('.').to_owned();
        Box::pin(async move {
            let addrs = resolve_ipv4(&host)
                .await
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
            Ok(Box::new(addrs.into_iter()) as Addrs)
        })
    }
}

/// Resolve `host` to IPv4 addresses via the OS resolver.
pub async fn resolve_ipv4(host: &str) -> Result<Vec<SocketAddr>, std::io::Error> {
    let host = host.trim().trim_end_matches('.');
    if host.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "empty host",
        ));
    }

    if let Ok(ip) = host.parse::<IpAddr>() {
        return match ip {
            IpAddr::V4(v4) => Ok(vec![SocketAddr::new(IpAddr::V4(v4), 0)]),
            IpAddr::V6(_) => Err(std::io::Error::new(
                std::io::ErrorKind::AddrNotAvailable,
                "IPv6 literal rejected (IPv4-only resolver)",
            )),
        };
    }

    let host = host.to_owned();
    tokio::task::spawn_blocking(move || lookup_ipv4_blocking(&host))
        .await
        .map_err(|e| std::io::Error::other(e))?
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
    let rc = unsafe { libc::getaddrinfo(c_host.as_ptr(), std::ptr::null(), &hints, &mut res) };
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

/// Reqwest builder that resolves portal hosts as IPv4 only.
pub fn ipv4_client_builder() -> reqwest::ClientBuilder {
    reqwest::Client::builder().dns_resolver(Arc::new(Ipv4Resolver))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn literal_ipv4() {
        let addrs = resolve_ipv4("127.0.0.1").await.unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv4());
    }

    #[tokio::test]
    async fn rejects_ipv6_literal() {
        assert!(resolve_ipv4("::1").await.is_err());
    }

    #[tokio::test]
    async fn localhost_is_ipv4() {
        let addrs = resolve_ipv4("localhost").await.expect("localhost");
        assert!(addrs.iter().all(|a| a.is_ipv4()));
        assert!(!addrs.is_empty());
    }
}
