use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

const CODE_TTL: Duration = Duration::from_secs(300);

#[derive(Debug, Clone, Serialize)]
pub struct DeviceRecord {
    pub device_id: String,
    pub token: String,
    pub paired_at: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
}

#[derive(Debug, Clone)]
struct ActiveCode {
    code: String,
    created_at: Instant,
    used: bool,
}

#[derive(Default)]
struct PairingInner {
    server_id: String,
    current_code: Option<ActiveCode>,
    devices: HashMap<String, DeviceRecord>,
    token_index: HashMap<String, String>,
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
        let record = DeviceRecord {
            device_id: device_id.to_string(),
            token: token.clone(),
            paired_at: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0),
            label,
        };
        if let Some(old) = g.devices.remove(device_id) {
            g.token_index.remove(&old.token);
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

    pub fn list_devices(&self) -> Vec<DeviceRecord> {
        self.inner
            .lock()
            .map(|g| {
                g.devices
                    .values()
                    .map(|d| DeviceRecord {
                        device_id: d.device_id.clone(),
                        token: mask_token(&d.token),
                        paired_at: d.paired_at,
                        label: d.label.clone(),
                    })
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn revoke_device(&self, device_id: &str) -> bool {
        let mut g = match self.inner.lock() {
            Ok(g) => g,
            Err(_) => return false,
        };
        if let Some(record) = g.devices.remove(device_id) {
            g.token_index.remove(&record.token);
            true
        } else {
            false
        }
    }
}

fn generate_token() -> String {
    let mut rng = rand::thread_rng();
    (0..32)
        .map(|_| {
            const CHARSET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
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
}
