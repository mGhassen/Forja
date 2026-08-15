use serde::Serialize;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

pub const DEFAULT_DISK_CACHE_BYTES: u64 = 2 * 1024 * 1024 * 1024;
pub const MIN_DISK_CACHE_BYTES: u64 = 256 * 1024 * 1024;
pub const MAX_DISK_CACHE_BYTES: u64 = 32 * 1024 * 1024 * 1024;

const DHT_STATE_FILE: &str = "dht_state.json";

#[derive(Debug, Clone, Default, Serialize, PartialEq)]
pub struct DiskCacheStats {
    pub capacity_bytes: u64,
    pub used_bytes: u64,
    pub protected_bytes: u64,
    pub evictions: u64,
    pub reclaimed_bytes: u64,
    pub over_budget: bool,
}

pub fn clamp_capacity_bytes(bytes: u64) -> u64 {
    bytes.clamp(MIN_DISK_CACHE_BYTES, MAX_DISK_CACHE_BYTES)
}

/// Delete idle files under [root] until [used] <= [target_bytes].
/// Never deletes [DHT_STATE_FILE] or paths in [protected_relpaths] (`/`-separated).
pub fn reclaim_download_dir(
    root: &Path,
    protected_relpaths: &HashSet<String>,
    target_bytes: u64,
    capacity_bytes: u64,
) -> Result<DiskCacheStats, String> {
    let mut stats = DiskCacheStats {
        capacity_bytes,
        ..DiskCacheStats::default()
    };
    if !root.exists() {
        return Ok(stats);
    }
    if !root.is_dir() {
        return Err("torrent cache root is not a directory".into());
    }

    let mut files: Vec<CacheFile> = Vec::new();
    collect_files(root, root, &mut files)?;

    let mut used: u64 = 0;
    let mut protected_bytes: u64 = 0;
    let mut idle: Vec<CacheFile> = Vec::new();
    for file in files {
        used = used.saturating_add(file.size);
        if is_protected(&file.rel, protected_relpaths) {
            protected_bytes = protected_bytes.saturating_add(file.size);
            continue;
        }
        idle.push(file);
    }

    idle.sort_by(|a, b| {
        a.mtime
            .cmp(&b.mtime)
            .then_with(|| a.rel.cmp(&b.rel))
    });

    let mut evictions = 0u64;
    let mut reclaimed = 0u64;
    for file in idle {
        if used <= target_bytes {
            break;
        }
        match fs::remove_file(&file.path) {
            Ok(()) => {
                used = used.saturating_sub(file.size);
                reclaimed = reclaimed.saturating_add(file.size);
                evictions = evictions.saturating_add(1);
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(format!("failed to evict {}: {e}", file.path.display())),
        }
    }

    prune_empty_dirs(root)?;

    stats.used_bytes = used;
    stats.protected_bytes = protected_bytes;
    stats.evictions = evictions;
    stats.reclaimed_bytes = reclaimed;
    stats.over_budget = used > capacity_bytes;
    Ok(stats)
}

struct CacheFile {
    path: PathBuf,
    rel: String,
    size: u64,
    mtime: SystemTime,
}

fn collect_files(root: &Path, dir: &Path, out: &mut Vec<CacheFile>) -> Result<(), String> {
    let entries = fs::read_dir(dir).map_err(|e| format!("read {}: {e}", dir.display()))?;
    for entry in entries {
        let entry = entry.map_err(|e| format!("read {}: {e}", dir.display()))?;
        let path = entry.path();
        let ft = entry
            .file_type()
            .map_err(|e| format!("stat {}: {e}", path.display()))?;
        if ft.is_symlink() {
            continue;
        }
        if ft.is_dir() {
            collect_files(root, &path, out)?;
            continue;
        }
        if !ft.is_file() {
            continue;
        }
        let rel = rel_key(root, &path).ok_or_else(|| {
            format!("cache path escaped root: {}", path.display())
        })?;
        if rel == DHT_STATE_FILE {
            continue;
        }
        let meta = fs::metadata(&path).map_err(|e| format!("stat {}: {e}", path.display()))?;
        let mtime = meta.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        out.push(CacheFile {
            path,
            rel,
            size: meta.len(),
            mtime,
        });
    }
    Ok(())
}

fn rel_key(root: &Path, path: &Path) -> Option<String> {
    let rel = path.strip_prefix(root).ok()?;
    if rel.components().any(|c| matches!(c, std::path::Component::ParentDir)) {
        return None;
    }
    Some(rel.to_string_lossy().replace('\\', "/"))
}

fn is_protected(rel: &str, protected: &HashSet<String>) -> bool {
    protected
        .iter()
        .any(|p| rel == p || rel.starts_with(&format!("{p}/")))
}

fn prune_empty_dirs(root: &Path) -> Result<(), String> {
    let mut dirs: Vec<PathBuf> = Vec::new();
    collect_dirs(root, root, &mut dirs)?;
    dirs.sort_by_key(|p| std::cmp::Reverse(p.components().count()));
    for dir in dirs {
        if dir == root {
            continue;
        }
        let _ = fs::remove_dir(&dir);
    }
    Ok(())
}

fn collect_dirs(root: &Path, dir: &Path, out: &mut Vec<PathBuf>) -> Result<(), String> {
    let entries = fs::read_dir(dir).map_err(|e| format!("read {}: {e}", dir.display()))?;
    for entry in entries {
        let entry = entry.map_err(|e| format!("read {}: {e}", dir.display()))?;
        let path = entry.path();
        let ft = entry
            .file_type()
            .map_err(|e| format!("stat {}: {e}", path.display()))?;
        if ft.is_dir() && !ft.is_symlink() {
            if rel_key(root, &path).is_none() {
                continue;
            }
            collect_dirs(root, &path, out)?;
            out.push(path);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write_file(path: &Path, bytes: &[u8]) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, bytes).unwrap();
    }

    #[test]
    fn clamp_capacity() {
        assert_eq!(clamp_capacity_bytes(1), MIN_DISK_CACHE_BYTES);
        assert_eq!(clamp_capacity_bytes(u64::MAX), MAX_DISK_CACHE_BYTES);
        assert_eq!(
            clamp_capacity_bytes(DEFAULT_DISK_CACHE_BYTES),
            DEFAULT_DISK_CACHE_BYTES
        );
    }

    #[test]
    fn missing_root_is_empty() {
        let root = std::env::temp_dir().join("forja_disk_cache_missing_test");
        let _ = fs::remove_dir_all(&root);
        let stats = reclaim_download_dir(&root, &HashSet::new(), 0, 1024).unwrap();
        assert_eq!(
            stats,
            DiskCacheStats {
                capacity_bytes: 1024,
                ..DiskCacheStats::default()
            }
        );
    }

    #[test]
    fn evicts_oldest_idle_until_under_target() {
        let root = std::env::temp_dir().join("forja_disk_cache_lru_test");
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        // Same-mtime fallback is name order — a_* evicts before z_*.
        write_file(&root.join("a_old.bin"), &[1; 100]);
        write_file(&root.join("z_new.bin"), &[2; 100]);
        write_file(&root.join(DHT_STATE_FILE), b"{}");

        let stats = reclaim_download_dir(&root, &HashSet::new(), 100, 100).unwrap();
        assert_eq!(stats.evictions, 1);
        assert_eq!(stats.reclaimed_bytes, 100);
        assert_eq!(stats.used_bytes, 100);
        assert!(!root.join("a_old.bin").exists());
        assert!(root.join("z_new.bin").exists());
        assert!(root.join(DHT_STATE_FILE).exists());
        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn never_deletes_protected_or_dht() {
        let root = std::env::temp_dir().join("forja_disk_cache_protect_test");
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        write_file(&root.join("keep").join("video.mkv"), &[3; 200]);
        write_file(&root.join("idle.bin"), &[4; 50]);
        write_file(&root.join(DHT_STATE_FILE), b"{}");

        let mut protected = HashSet::new();
        protected.insert("keep/video.mkv".into());
        let stats = reclaim_download_dir(&root, &protected, 0, 10).unwrap();
        assert!(root.join("keep/video.mkv").exists());
        assert!(!root.join("idle.bin").exists());
        assert!(root.join(DHT_STATE_FILE).exists());
        assert_eq!(stats.protected_bytes, 200);
        assert!(stats.over_budget);
        let _ = fs::remove_dir_all(&root);
    }
}
