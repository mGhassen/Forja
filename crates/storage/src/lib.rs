use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::{LazyLock, Mutex};

static STORE: LazyLock<Mutex<EngineStore>> =
    LazyLock::new(|| Mutex::new(EngineStore::default()));

#[derive(Default)]
struct EngineStore {
    path: Option<PathBuf>,
    data: HashMap<String, Value>,
}

impl EngineStore {
    fn open(path: &str) -> Result<(), String> {
        let path = PathBuf::from(path);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        let data = if path.exists() {
            let raw = fs::read_to_string(&path).map_err(|e| e.to_string())?;
            if raw.trim().is_empty() {
                HashMap::new()
            } else {
                serde_json::from_str(&raw).map_err(|e| e.to_string())?
            }
        } else {
            HashMap::new()
        };
        let mut guard = STORE.lock().map_err(|_| "storage lock poisoned".to_string())?;
        guard.path = Some(path);
        guard.data = data;
        Ok(())
    }

    fn get(&self, key: &str) -> Option<Value> {
        self.data.get(key).cloned()
    }

    fn set(&mut self, key: &str, value: Value) -> Result<(), String> {
        self.data.insert(key.to_string(), value);
        self.flush()
    }

    fn flush(&self) -> Result<(), String> {
        let path = self.path.as_ref().ok_or("storage not open")?;
        let json = serde_json::to_string_pretty(&self.data).map_err(|e| e.to_string())?;
        fs::write(path, json).map_err(|e| e.to_string())
    }
}

pub fn open(path: &str) -> Result<(), String> {
    EngineStore::open(path)
}

pub fn get(key: &str) -> Option<Value> {
    STORE
        .lock()
        .ok()
        .and_then(|guard| guard.get(key))
}

pub fn set(key: &str, value: Value) -> Result<(), String> {
    STORE
        .lock()
        .map_err(|_| "storage lock poisoned".to_string())?
        .set(key, value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_path(name: &str) -> String {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir()
            .join(format!("forja_storage_{name}_{nanos}.json"))
            .to_string_lossy()
            .into_owned()
    }

    #[test]
    fn round_trip_string_list() {
        let path = temp_path("list");
        open(&path).unwrap();
        set(
            "forja_provider_order",
            serde_json::json!(["videasy", "vidsrc"]),
        )
        .unwrap();
        drop(STORE.lock().unwrap());
        open(&path).unwrap();
        let v = get("forja_provider_order").unwrap();
        assert_eq!(v, serde_json::json!(["videasy", "vidsrc"]));
        let _ = fs::remove_file(path);
    }
}
