//! System DNS for IPTV portals.
//!
//! Real IPv4 and real IPv6 are both kept. A DNS64 translation (`64:ff9b::/96`)
//! is dropped when a real address exists, because connecting to it hangs on
//! networks that are not NAT64. If that translation is the only answer, it
//! is kept so an IPv6-only network can still connect.

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::sync::Arc;

use reqwest::dns::{Addrs, Name, Resolve, Resolving};

struct PortalResolver;

impl Resolve for PortalResolver {
    fn resolve(&self, name: Name) -> Resolving {
        let host = name.as_str().trim_end_matches('.').to_owned();
        Box::pin(async move {
            let addrs = resolve_host(&host)
                .await
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
            Ok(Box::new(addrs.into_iter()) as Addrs)
        })
    }
}

/// DNS64 well-known prefix (RFC 6052). This AAAA is a translated IPv4 address.
pub fn is_nat64(ip: IpAddr) -> bool {
    let IpAddr::V6(v6) = ip else {
        return false;
    };
    v6.to_string().starts_with("64:ff9b:")
}

/// Keep real IPv4 and real IPv6. Drop `64:ff9b` translations when anything
/// real is present. A translation-only answer is kept.
pub fn prefer_routable(addrs: Vec<SocketAddr>) -> Vec<SocketAddr> {
    let mut v4 = Vec::new();
    let mut real_v6 = Vec::new();
    let mut nat64 = Vec::new();
    for addr in addrs {
        match addr.ip() {
            IpAddr::V4(_) => v4.push(addr),
            IpAddr::V6(_) if is_nat64(addr.ip()) => nat64.push(addr),
            IpAddr::V6(_) => real_v6.push(addr),
        }
    }
    if !v4.is_empty() {
        v4.extend(real_v6);
        return v4;
    }
    if !real_v6.is_empty() {
        return real_v6;
    }
    nat64
}

/// Resolve `host` with the OS resolver, then [prefer_routable].
pub async fn resolve_host(host: &str) -> Result<Vec<SocketAddr>, std::io::Error> {
    let host = host.trim().trim_end_matches('.');
    if host.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "empty host",
        ));
    }

    if let Ok(ip) = host.parse::<IpAddr>() {
        return Ok(prefer_routable(vec![SocketAddr::new(ip, 0)]));
    }

    let host_owned = host.to_owned();
    let unspec =
        tokio::task::spawn_blocking(move || lookup_blocking(&host_owned, QueryFamily::Any))
            .await
            .map_err(|e| std::io::Error::other(e))?;
    let unspec = unspec.unwrap_or_default();
    let picked = prefer_routable(unspec);
    if picked.iter().any(|a| !is_nat64(a.ip())) {
        return Ok(picked);
    }

    let host_v4 = host.to_owned();
    let v4 = tokio::task::spawn_blocking(move || lookup_blocking(&host_v4, QueryFamily::V4))
        .await
        .map_err(|e| std::io::Error::other(e))?
        .unwrap_or_default();
    if !v4.is_empty() {
        return Ok(v4);
    }
    if !picked.is_empty() {
        return Ok(picked);
    }
    Err(std::io::Error::new(
        std::io::ErrorKind::AddrNotAvailable,
        format!("no addresses for {host}"),
    ))
}

#[derive(Clone, Copy)]
enum QueryFamily {
    Any,
    V4,
}

fn lookup_failed(rc: i32) -> std::io::Error {
    std::io::Error::new(
        std::io::ErrorKind::Other,
        format!("getaddrinfo failed ({rc})"),
    )
}

fn no_addresses(host: &str) -> std::io::Error {
    std::io::Error::new(
        std::io::ErrorKind::AddrNotAvailable,
        format!("no addresses for {host}"),
    )
}

#[cfg(unix)]
fn lookup_blocking(host: &str, family: QueryFamily) -> Result<Vec<SocketAddr>, std::io::Error> {
    use std::ffi::CString;

    let family = match family {
        QueryFamily::Any => libc::AF_UNSPEC,
        QueryFamily::V4 => libc::AF_INET,
    };
    let c_host =
        CString::new(host).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidInput, e))?;

    let mut hints: libc::addrinfo = unsafe { std::mem::zeroed() };
    hints.ai_family = family;
    hints.ai_socktype = libc::SOCK_STREAM;

    let mut res: *mut libc::addrinfo = std::ptr::null_mut();
    let rc = unsafe { libc::getaddrinfo(c_host.as_ptr(), std::ptr::null(), &hints, &mut res) };
    if rc != 0 {
        return Err(lookup_failed(rc));
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
            } else if ai.ai_family == libc::AF_INET6 && !ai.ai_addr.is_null() {
                let sin6 = &*(ai.ai_addr as *const libc::sockaddr_in6);
                let ip = Ipv6Addr::from(sin6.sin6_addr.s6_addr);
                out.push(SocketAddr::new(IpAddr::V6(ip), 0));
            }
            cur = ai.ai_next;
        }
    }
    unsafe { libc::freeaddrinfo(res) };

    if out.is_empty() {
        return Err(no_addresses(host));
    }
    Ok(out)
}

/// WinSock `ADDRINFOA` is not the POSIX `addrinfo` that `libc` exports, so
/// Windows cannot use the Unix lookup.
#[cfg(windows)]
fn lookup_blocking(host: &str, family: QueryFamily) -> Result<Vec<SocketAddr>, std::io::Error> {
    use std::ffi::CString;
    use std::sync::OnceLock;
    use windows_sys::Win32::Networking::WinSock::{
        freeaddrinfo, getaddrinfo, WSAStartup, ADDRINFOA, AF_INET, AF_INET6, AF_UNSPEC,
        SOCKADDR_IN, SOCKADDR_IN6, SOCK_STREAM, WSADATA,
    };

    fn ensure_winsock() -> Result<(), std::io::Error> {
        static READY: OnceLock<i32> = OnceLock::new();
        let rc = *READY.get_or_init(|| {
            let mut data = unsafe { std::mem::zeroed::<WSADATA>() };
            unsafe { WSAStartup(0x0202, &mut data) }
        });
        if rc == 0 {
            Ok(())
        } else {
            Err(std::io::Error::from_raw_os_error(rc))
        }
    }

    ensure_winsock()?;

    let family = match family {
        QueryFamily::Any => i32::from(AF_UNSPEC),
        QueryFamily::V4 => i32::from(AF_INET),
    };
    let c_host =
        CString::new(host).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidInput, e))?;

    let mut hints: ADDRINFOA = unsafe { std::mem::zeroed() };
    hints.ai_family = family;
    hints.ai_socktype = SOCK_STREAM;

    let mut res: *mut ADDRINFOA = std::ptr::null_mut();
    let rc = unsafe {
        getaddrinfo(
            c_host.as_ptr() as *const u8,
            std::ptr::null(),
            &hints,
            &mut res,
        )
    };
    if rc != 0 {
        return Err(lookup_failed(rc));
    }

    let mut out = Vec::new();
    let mut cur = res;
    while !cur.is_null() {
        unsafe {
            let ai = &*cur;
            if ai.ai_family == i32::from(AF_INET) && !ai.ai_addr.is_null() {
                let sin = &*(ai.ai_addr as *const SOCKADDR_IN);
                let ip = Ipv4Addr::from(u32::from_be(sin.sin_addr.S_un.S_addr));
                out.push(SocketAddr::new(IpAddr::V4(ip), 0));
            } else if ai.ai_family == i32::from(AF_INET6) && !ai.ai_addr.is_null() {
                let sin6 = &*(ai.ai_addr as *const SOCKADDR_IN6);
                let ip = Ipv6Addr::from(sin6.sin6_addr.u.Byte);
                out.push(SocketAddr::new(IpAddr::V6(ip), 0));
            }
            cur = ai.ai_next;
        }
    }
    unsafe { freeaddrinfo(res) };

    if out.is_empty() {
        return Err(no_addresses(host));
    }
    Ok(out)
}

#[cfg(not(any(unix, windows)))]
fn lookup_blocking(host: &str, family: QueryFamily) -> Result<Vec<SocketAddr>, std::io::Error> {
    let _ = (host, family);
    Err(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        "system DNS is not available on this target",
    ))
}

/// Reqwest builder for portal HTTP. Real IPv6 is included. DNS64 translations
/// are not, unless they are the only address.
pub fn portal_client_builder() -> reqwest::ClientBuilder {
    reqwest::Client::builder().dns_resolver(Arc::new(PortalResolver))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn v4(octets: [u8; 4]) -> SocketAddr {
        SocketAddr::new(IpAddr::V4(Ipv4Addr::from(octets)), 0)
    }

    fn v6(text: &str) -> SocketAddr {
        SocketAddr::new(text.parse::<Ipv6Addr>().unwrap().into(), 0)
    }

    #[test]
    fn keeps_real_ipv6_and_drops_nat64_when_ipv4_exists() {
        let out = prefer_routable(vec![
            v6("64:ff9b::c000:201"),
            v4([192, 0, 2, 1]),
            v6("2001:db8::1"),
        ]);
        assert_eq!(out.len(), 2);
        assert!(out[0].is_ipv4());
        assert_eq!(out[1].ip(), "2001:db8::1".parse::<IpAddr>().unwrap());
    }

    #[test]
    fn keeps_real_ipv6_alone() {
        let out = prefer_routable(vec![v6("2001:db8::1")]);
        assert_eq!(out.len(), 1);
        assert!(out[0].is_ipv6());
    }

    #[test]
    fn keeps_nat64_when_it_is_the_only_address() {
        let out = prefer_routable(vec![v6("64:ff9b::c000:201")]);
        assert_eq!(out.len(), 1);
        assert!(is_nat64(out[0].ip()));
    }

    #[tokio::test]
    async fn literal_ipv4() {
        let addrs = resolve_host("127.0.0.1").await.unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv4());
    }

    #[tokio::test]
    async fn literal_ipv6_is_kept() {
        let addrs = resolve_host("::1").await.unwrap();
        assert_eq!(addrs.len(), 1);
        assert!(addrs[0].is_ipv6());
    }

    #[tokio::test]
    async fn localhost_resolves() {
        let addrs = resolve_host("localhost").await.expect("localhost");
        assert!(!addrs.is_empty());
    }
}
