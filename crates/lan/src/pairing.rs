use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

const CODE_TTL: Duration = Duration::from_secs(300);
const STREAM_TICKET_TTL: Duration = Duration::from_secs(12 * 60 * 60);

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceRecord {
    pub device_id: String,
    pub token: String,
    pub paired_at: u64,
    /// Unix seconds of last authenticated control/stream request (0 = never).
    #[serde(default)]
    pub last_seen: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
}

#[derive(Debug, Clone)]
struct ActiveCode {
    code: String,
    created_at: Instant,
    used: bool,
}

#[derive(Debug, Clone)]
struct StreamTicket {
    device_id: String,
    created_at: Instant,
}

#[derive(Default)]
struct PairingInner {
    server_id: String,
    current_code: Option<ActiveCode>,
    devices: HashMap<String, DeviceRecord>,
    token_index: HashMap<String, String>,
    stream_tickets: HashMap<String, StreamTicket>,
}

#[derive(Clone)]
pub struct PairingState {
    inner: Arc<Mutex<PairingInner>>,
}

impl PairingState {
    pub fn new(server_id: String) -> Self {
        Self {
            inner: Arc::new(Mutex::new(PairingInner {
                server_id,
                ..Default::default()
            })),
        }
    }

    pub fn server_id(&self) -> String {
        self.inner
            .lock()
            .map(|g| g.server_id.clone())
            .unwrap_or_default()
    }

    pub fn refresh_code(&self) -> String {
        let mut rng = rand::thread_rng();
        let code: String = (0..6)
            .map(|_| rng.gen_range(0..10).to_string())
            .collect();
        if let Ok(mut g) = self.inner.lock() {
            g.current_code = Some(ActiveCode {
                code: code.clone(),
                created_at: Instant::now(),
                used: false,
            });
        }
        code
    }

    pub fn current_code(&self) -> Option<String> {
        let g = self.inner.lock().ok()?;
        let code = g.current_code.as_ref()?;
        if code.used || code.created_at.elapsed() > CODE_TTL {
            return None;
        }
        Some(code.code.clone())
    }

    pub fn pair(
        &self,
        code: &str,
        device_id: &str,
        label: Option<String>,
    ) -> Result<String, String> {
        let mut g = self.inner.lock().map_err(|_| "pairing lock poisoned")?;
        let active = g
            .current_code
            .as_ref()
            .ok_or_else(|| "No active pairing code".to_string())?;
        if active.used {
            return Err("Pairing code already used".to_string());
        }
        if active.created_at.elapsed() > CODE_TTL {
            return Err("Pairing code expired".to_string());
        }
        if active.code != code {
            return Err("Invalid pairing code".to_string());
        }

        let token = generate_token();
        let now = unix_secs();
        let record = DeviceRecord {
            device_id: device_id.to_string(),
            token: token.clone(),
            paired_at: now,
            last_seen: now,
            label,
        };
        if let Some(old) = g.devices.remove(device_id) {
            g.token_index.remove(&old.token);
            g.stream_tickets.retain(|_, t| t.device_id != device_id);
        }
        g.token_index
            .insert(token.clone(), device_id.to_string());
        g.devices.insert(device_id.to_string(), record);
        if let Some(c) = g.current_code.as_mut() {
            c.used = true;
        }
        Ok(token)
    }

    pub fn validate_token(&self, token: &str) -> bool {
        self.inner
            .lock()
            .map(|g| g.token_index.contains_key(token))
            .unwrap_or(false)
    }

    /// Mark device active (Bearer control-plane hit).
    pub fn touch_token(&self, token: &str) {
        let Ok(mut g) = self.inner.lock() else {
            return;
        };
        let Some(device_id) = g.token_index.get(token).cloned() else {
            return;
        };
        if let Some(rec) = g.devices.get_mut(&device_id) {
            rec.last_seen = unix_secs();
        }
    }

    /// Mark device active (stream ticket media GET).
    pub fn touch_stream_ticket(&self, ticket: &str) {
        let Ok(mut g) = self.inner.lock() else {
            return;
        };
        let Some(entry) = g.stream_tickets.get(ticket) else {
            return;
        };
        let device_id = entry.device_id.clone();
        if let Some(rec) = g.devices.get_mut(&device_id) {
            rec.last_seen = unix_secs();
        }
    }

    /// `(device_id, label)` for a live device token.
    pub fn device_for_token(&self, token: &str) -> Option<(String, Option<String>)> {
        let g = self.inner.lock().ok()?;
        let device_id = g.token_index.get(token)?.clone();
        let label = g.devices.get(&device_id).and_then(|d| d.label.clone());
        Some((device_id, label))
    }

    pub fn mint_stream_ticket(&self, device_token: &str) -> Result<String, String> {
        let mut g = self.inner.lock().map_err(|_| "pairing lock poisoned")?;
        let device_id = g
            .token_index
            .get(device_token)
            .cloned()
            .ok_or_else(|| "Invalid device token".to_string())?;
        let ticket = generate_token();
        g.stream_tickets.insert(
            ticket.clone(),
            StreamTicket {
                device_id,
                created_at: Instant::now(),
            },
        );
        Ok(ticket)
    }

    pub fn validate_stream_ticket(&self, ticket: &str) -> bool {
        let mut g = match self.inner.lock() {
            Ok(g) => g,
            Err(_) => return false,
        };
        let Some(entry) = g.stream_tickets.get(ticket) else {
            return false;
        };
        if entry.created_at.elapsed() > STREAM_TICKET_TTL {
            g.stream_tickets.remove(ticket);
            return false;
        }
        true
    }

    pub fn list_devices(&self) -> Vec<DeviceRecord> {
        self.inner
            .lock()
            .map(|g| {
                let mut out: Vec<_> = g
                    .devices
                    .values()
                    .map(|d| DeviceRecord {
                        device_id: d.device_id.clone(),
                        token: mask_token(&d.token),
                        paired_at: d.paired_at,
                        last_seen: d.last_seen,
                        label: d.label.clone(),
                    })
                    .collect();
                out.sort_by(|a, b| b.paired_at.cmp(&a.paired_at));
                out
            })
            .unwrap_or_default()
    }

    /// Full tokens for durable storage (not for API responses).
    pub fn export_devices(&self) -> Vec<DeviceRecord> {
        self.inner
            .lock()
            .map(|g| g.devices.values().cloned().collect())
            .unwrap_or_default()
    }

    pub fn restore_devices(&self, records: Vec<DeviceRecord>) {
        let Ok(mut g) = self.inner.lock() else {
            return;
        };
        g.devices.clear();
        g.token_index.clear();
        for record in records {
            if record.device_id.is_empty() || record.token.is_empty() {
                continue;
            }
            g.token_index
                .insert(record.token.clone(), record.device_id.clone());
            g.devices.insert(record.device_id.clone(), record);
        }
    }

    pub fn revoke_device(&self, device_id: &str) -> bool {
        let mut g = match self.inner.lock() {
            Ok(g) => g,
            Err(_) => return false,
        };
        if let Some(record) = g.devices.remove(device_id) {
            g.token_index.remove(&record.token);
            g.stream_tickets.retain(|_, t| t.device_id != device_id);
            true
        } else {
            false
        }
    }
}

fn unix_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn generate_token() -> String {
    let mut rng = rand::thread_rng();
    (0..32)
        .map(|_| {
            const CHARSET: &[u8] =
                b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            CHARSET[rng.gen_range(0..CHARSET.len())] as char
        })
        .collect()
}

fn mask_token(token: &str) -> String {
    if token.len() <= 8 {
        return "****".to_string();
    }
    format!("{}…{}", &token[..4], &token[token.len() - 4..])
}

#[derive(Debug, Deserialize)]
pub struct PairRequest {
    pub code: String,
    pub device_id: String,
    #[serde(default)]
    pub label: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct PairResponse {
    pub token: String,
    pub server_id: String,
}

#[derive(Debug, Deserialize)]
pub struct RevokeRequest {
    pub device_id: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pair_once_rejects_reuse() {
        let state = PairingState::new("srv1".into());
        let code = state.refresh_code();
        let token = state.pair(&code, "phone-1", None).expect("pair");
        assert!(!token.is_empty());
        assert!(state.pair(&code, "phone-2", None).is_err());
    }

    #[test]
    fn revoke_removes_token() {
        let state = PairingState::new("srv1".into());
        let code = state.refresh_code();
        let token = state.pair(&code, "phone-1", None).expect("pair");
        assert!(state.validate_token(&token));
        assert!(state.revoke_device("phone-1"));
        assert!(!state.validate_token(&token));
    }

    #[test]
    fn stream_ticket_requires_device_token() {
        let state = PairingState::new("srv1".into());
        let code = state.refresh_code();
        let token = state.pair(&code, "tv-1", None).expect("pair");
        let ticket = state.mint_stream_ticket(&token).expect("ticket");
        assert!(state.validate_stream_ticket(&ticket));
        assert!(state.mint_stream_ticket("bad").is_err());
        assert!(state.revoke_device("tv-1"));
        assert!(!state.validate_stream_ticket(&ticket));
    }

    #[test]
    fn touch_token_updates_last_seen() {
        let state = PairingState::new("srv1".into());
        let code = state.refresh_code();
        let token = state.pair(&code, "tv-1", Some("Android TV".into())).expect("pair");
        let before = state.list_devices()[0].last_seen;
        assert!(before > 0);
        std::thread::sleep(Duration::from_millis(20));
        state.touch_token(&token);
        let after = state.list_devices()[0].last_seen;
        assert!(after >= before);
    }
}
