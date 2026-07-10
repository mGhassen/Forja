use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use serde::{Deserialize, Serialize};
use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::Duration;

const SERVICE_TYPE: &str = "_forja._tcp.local.";

pub struct MdnsAnnouncer {
    daemon: Option<ServiceDaemon>,
    _service_name: String,
}

impl MdnsAnnouncer {
    pub fn announce(
        server_id: &str,
        port: u16,
        version: &str,
    ) -> Result<Self, String> {
        let daemon = ServiceDaemon::new().map_err(|e| e.to_string())?;
        let host = local_lan_ip().unwrap_or_else(|| "127.0.0.1".to_string());
        let service_name = format!("Forja-{server_id}");
        let instance = format!("{service_name}.{SERVICE_TYPE}");
        let properties = [
            ("server_id", server_id),
            ("version", version),
        ];
        let info = ServiceInfo::new(
            SERVICE_TYPE,
            &service_name,
            &format!("{host}."),
            &host,
            port,
            &properties[..],
        )
        .map_err(|e| e.to_string())?;
        daemon
            .register(info)
            .map_err(|e| e.to_string())?;
        Ok(Self {
            daemon: Some(daemon),
            _service_name: instance,
        })
    }

    pub fn stop(&mut self) {
        self.daemon.take();
    }
}

impl Drop for MdnsAnnouncer {
    fn drop(&mut self) {
        self.stop();
    }
}

fn local_lan_ip() -> Option<String> {
    let socket = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.connect("8.8.8.8:80").ok()?;
    let addr = socket.local_addr().ok()?;
    match addr.ip() {
        IpAddr::V4(v4) if !v4.is_loopback() => Some(v4.to_string()),
        _ => None,
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DiscoveredServer {
    pub server_id: String,
    pub host: String,
    pub port: u16,
    pub version: Option<String>,
}

pub fn browse_forja_servers(timeout: Duration) -> Vec<DiscoveredServer> {
    let daemon = match ServiceDaemon::new() {
        Ok(d) => d,
        Err(_) => return Vec::new(),
    };
    let receiver: mdns_sd::Receiver<ServiceEvent> = match daemon.browse(SERVICE_TYPE) {
        Ok(r) => r,
        Err(_) => return Vec::new(),
    };
    let found: Arc<Mutex<Vec<DiscoveredServer>>> = Arc::new(Mutex::new(Vec::new()));
    let deadline = std::time::Instant::now() + timeout;
    while std::time::Instant::now() < deadline {
        match receiver.recv_timeout(Duration::from_millis(200)) {
            Ok(ServiceEvent::ServiceResolved(info)) => {
                let host = info
                    .get_addresses()
                    .iter()
                    .find(|ip| ip.is_ipv4())
                    .map(|ip| ip.to_string())
                    .unwrap_or_else(|| info.get_hostname().to_string());
                let port = info.get_port();
                let server_id = info
                    .get_property_val_str("server_id")
                    .unwrap_or("")
                    .to_string();
                let version = info.get_property_val_str("version").map(str::to_string);
                let entry = DiscoveredServer {
                    server_id,
                    host,
                    port,
                    version,
                };
                if let Ok(mut list) = found.lock() {
                    if !list.iter().any(|s| s.host == entry.host && s.port == entry.port) {
                        list.push(entry);
                    }
                }
            }
            Ok(_) => {}
            Err(_) => break,
        }
    }
    found.lock().map(|g| g.clone()).unwrap_or_default()
}
