use serde_json::Value;
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
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
        let data = load_json_map(&path)?;
        let mut guard = STORE
            .lock()
            .map_err(|_| "storage lock poisoned".to_string())?;
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
        atomic_write(path, json.as_bytes())
    }
}

/// Read the canonical settings file, falling back to a sibling `.bak` if the
/// primary file is empty or corrupt (e.g. crash mid-write before atomic rename).
fn load_json_map(path: &Path) -> Result<HashMap<String, Value>, String> {
    if path.exists() {
        match read_map_file(path) {
            Ok(map) => return Ok(map),
            Err(primary_err) => {
                let bak = backup_path(path);
                if bak.exists() {
                    if let Ok(map) = read_map_file(&bak) {
                        // Restore the last known-good file.
                        let _ = fs::copy(&bak, path);
                        return Ok(map);
                    }
                }
                return Err(primary_err);
            }
        }
    }
    let bak = backup_path(path);
    if bak.exists() {
        if let Ok(map) = read_map_file(&bak) {
            let _ = fs::copy(&bak, path);
            return Ok(map);
        }
    }
    Ok(HashMap::new())
}

fn read_map_file(path: &Path) -> Result<HashMap<String, Value>, String> {
    let raw = fs::read_to_string(path).map_err(|e| e.to_string())?;
    if raw.trim().is_empty() {
        return Ok(HashMap::new());
    }
    serde_json::from_str(&raw).map_err(|e| e.to_string())
}

fn backup_path(path: &Path) -> PathBuf {
    let mut bak = path.as_os_str().to_owned();
    bak.push(".bak");
    PathBuf::from(bak)
}

/// Write via temp file + fsync + rename so a crash cannot leave a truncated JSON body.
fn atomic_write(path: &Path, bytes: &[u8]) -> Result<(), String> {
    let parent = path
        .parent()
        .ok_or_else(|| "storage path has no parent".to_string())?;
    fs::create_dir_all(parent).map_err(|e| e.to_string())?;

    let tmp = path.with_extension("json.tmp");
    {
        let mut file = File::create(&tmp).map_err(|e| e.to_string())?;
        file.write_all(bytes).map_err(|e| e.to_string())?;
        file.sync_all().map_err(|e| e.to_string())?;
    }

    fs::rename(&tmp, path).map_err(|e| e.to_string())?;

    // Refresh last-known-good backup only after a successful replace.
    let bak = backup_path(path);
    let _ = fs::copy(path, &bak);

    // Best-effort directory sync so the rename itself is durable.
    if let Ok(dir) = File::open(parent) {
        let _ = dir.sync_all();
    }
    Ok(())
}

pub fn open(path: &str) -> Result<(), String> {
    EngineStore::open(path)
}

pub fn get(key: &str) -> Option<Value> {
    STORE.lock().ok().and_then(|guard| guard.get(key))
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
    use std::sync::Mutex as StdMutex;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// EngineStore is process-global; serialize unit tests that touch it.
    static TEST_LOCK: StdMutex<()> = StdMutex::new(());

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
        let _guard = TEST_LOCK.lock().unwrap();
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
        let _ = fs::remove_file(&path);
        let _ = fs::remove_file(backup_path(Path::new(&path)));
    }

    #[test]
    fn atomic_write_leaves_valid_json() {
        let _guard = TEST_LOCK.lock().unwrap();
        let path = temp_path("atomic");
        open(&path).unwrap();
        set("stream_provider_order", serde_json::json!(["videasy"])).unwrap();
        let raw = fs::read_to_string(&path).unwrap();
        let parsed: HashMap<String, Value> = serde_json::from_str(&raw).unwrap();
        assert_eq!(parsed["stream_provider_order"], serde_json::json!(["videasy"]));
        assert!(!Path::new(&path).with_extension("json.tmp").exists());
        assert!(backup_path(Path::new(&path)).exists());
        let _ = fs::remove_file(&path);
        let _ = fs::remove_file(backup_path(Path::new(&path)));
    }

    #[test]
    fn open_recovers_from_backup_when_primary_corrupt() {
        let _guard = TEST_LOCK.lock().unwrap();
        let path = temp_path("recover");
        open(&path).unwrap();
        set("navbar_config", serde_json::json!(["home", "search"])).unwrap();
        assert!(
            backup_path(Path::new(&path)).exists(),
            "expected .bak after successful write"
        );
        drop(STORE.lock().unwrap());

        // Simulate interrupted write: corrupt primary, keep .bak.
        fs::write(&path, "{truncated").unwrap();
        open(&path).unwrap();
        let v = get("navbar_config").unwrap();
        assert_eq!(v, serde_json::json!(["home", "search"]));
        let _ = fs::remove_file(&path);
        let _ = fs::remove_file(backup_path(Path::new(&path)));
    }
}
