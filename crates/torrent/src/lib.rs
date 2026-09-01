use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, StatusCode},
    response::Response,
    routing::get,
    Router,
};
use utils::{episode_matcher, torrent_filter};
use futures_util::TryStreamExt;
use librqbit::api::{Api, TorrentDetailsResponseFile, TorrentIdOrHash};
use librqbit::dht::DhtPersistenceConfig;
use librqbit::{
    AddTorrent, AddTorrentOptions, AddTorrentResponse, DhtSessionConfig, ListenerMode,
    ListenerOptions, Session, SessionOptions,
};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncSeekExt};
use tokio::net::TcpSocket;
use tokio::sync::oneshot;
use tokio_util::io::ReaderStream;

mod disk_cache;
pub use disk_cache::{clamp_capacity_bytes, DiskCacheStats, DEFAULT_DISK_CACHE_BYTES};

/// Prefer this many head bytes before handing the URL to mpv (container probe).
/// 64 KiB was too thin for some x265/MP4 probes; mpv then range-sought the
/// undownloaded tail while the swarm filled the middle (black screen + GBs).
const STREAM_HEAD_BYTES: u64 = 256 * 1024;
/// On timeout, still succeed if we got at least this many — mpv keeps pulling.
const STREAM_HEAD_MIN_ACCEPT: u64 = 64 * 1024;
/// Healthy swarms can take >60s after a cold DHT; desktop clients keep waiting.
const STREAM_HEAD_TIMEOUT: Duration = Duration::from_secs(180);

/// `session.add_torrent` for a magnet **includes DHT/tracker metadata resolve**
/// (librqbit has no separate metadata step). An 8s cap made healthy but slow
/// swarms fail while desktop clients (PlayTorr / qBittorrent) still worked.
const MAGNET_ADD_TIMEOUT: Duration = Duration::from_secs(90);
/// A metadata cache avoids depending solely on DHT peers that support
/// `ut_metadata`. The downloaded metainfo is hash-validated before use.
const METADATA_CACHE_TIMEOUT: Duration = Duration::from_secs(12);
const METADATA_CACHE_BASE_URL: &str = "https://itorrents.net/torrent";
const TORRENT_INIT_TIMEOUT: Duration = Duration::from_secs(30);

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TorrentStatus {
    pub name: String,
    #[serde(default)]
    pub info_hash: String,
    pub progress: f64,
    pub download_rate: u64,
    pub upload_rate: u64,
    pub num_peers: u32,
    pub num_seen: u32,
    pub progress_bytes: u64,
    pub total_bytes: u64,
    pub eta_secs: u64,
    pub state: String,
}

/// Disk + in-session download usage for the Sources panel cache row.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DownloadCacheSnapshot {
    pub cache_dir: String,
    pub disk_bytes: u64,
    pub progress_bytes: u64,
    pub total_bytes: u64,
    pub torrent_count: u32,
    pub active: bool,
}

#[derive(Debug, Serialize)]
pub struct StreamResponse {
    pub url: String,
    pub torrent_id: usize,
    pub file_idx: usize,
    pub info_hash: String,
}

#[derive(Debug, Serialize)]
struct StreamError {
    error: String,
}

#[derive(Debug, Serialize)]
struct TorrentFileEntry {
    index: usize,
    name: String,
    size: u64,
}

#[derive(Debug, Serialize)]
struct ListFilesResponse {
    torrent_id: usize,
    info_hash: String,
    files: Vec<TorrentFileEntry>,
}

struct PreparedTorrent {
    torrent_id: usize,
    info_hash: String,
    files: Vec<TorrentDetailsResponseFile>,
}

#[derive(Clone)]
pub struct TorrentAppState {
    pub api: Api,
}

#[derive(Clone)]
struct ActiveTorrent {
    id: usize,
    info_hash: String,
    file_idx: usize,
}

struct EngineInner {
    session: Option<Arc<Session>>,
    api: Option<Api>,
    http_port: u16,
    http_shutdown: Option<oneshot::Sender<()>>,
    active: Option<ActiveTorrent>,
    peer_limit: usize,
    disk_cache_capacity_bytes: u64,
    /// Background read at a scrub/hover byte offset — boosts librqbit piece priority.
    prefetch_task: Option<tokio::task::JoinHandle<()>>,
}

pub struct TorrentEngine {
    inner: Mutex<EngineInner>,
    runtime: tokio::runtime::Runtime,
}

impl Default for TorrentEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TorrentEngine {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(EngineInner {
                session: None,
                api: None,
                http_port: 0,
                http_shutdown: None,
                active: None,
                peer_limit: 128,
                disk_cache_capacity_bytes: DEFAULT_DISK_CACHE_BYTES,
                prefetch_task: None,
            }),
            runtime: tokio::runtime::Runtime::new().expect("tokio runtime"),
        }
    }

    fn download_dir() -> PathBuf {
        std::env::temp_dir().join("torrent")
    }

    /// Sandbox-safe session: DHT under our writable temp dir (not
    /// `~/Library/Caches/com.rqbit.dht`), TCP listen for incoming peers, no LSD.
    fn session_options(peer_limit: usize) -> SessionOptions {
        let dht_path = Self::download_dir().join("dht_state.json");
        SessionOptions {
            peer_limit: Some(peer_limit),
            dht: Some(DhtSessionConfig {
                persistence: Some(DhtPersistenceConfig {
                    dump_interval: Some(Duration::from_secs(60)),
                    config_filename: Some(dht_path),
                }),
                // Always ephemeral: librqbit otherwise rebinds the port stored in
                // dht_state.json, which fails when another Forja/test holds it
                // ("error initializing persistent DHT"). Routing table still loads.
                port: Some(0),
                // Default bootstraps include dead hosts (router.bittorrent.com).
                // Pin nodes that answer UDP from this network.
                bootstrap_addrs: Some(vec![
                    "dht.transmissionbt.com:6881".into(),
                    "dht.libtorrent.org:25401".into(),
                    "router.bittorrent.com:6881".into(),
                    "dht.aelitis.com:6881".into(),
                ]),
                ..Default::default()
            }),
            // Outgoing-only was the main gap vs qBittorrent / PlayTorr: many
            // swarms never push pieces until we accept inbound connections.
            listen: Some(ListenerOptions {
                mode: ListenerMode::TcpOnly,
                listen_addr: SocketAddr::from(([0, 0, 0, 0], 0)),
                enable_upnp_port_forwarding: false,
                ipv4_only: true,
                ..Default::default()
            }),
            // Magnets often ship with few/dead `tr=` entries. Desktop clients keep a
            // default tracker list — without it, metadata resolve stalls on DHT alone.
            trackers: Self::default_public_trackers(),
            disable_local_service_discovery: true,
            ipv4_only: true,
            ..Default::default()
        }
    }

    fn default_public_trackers() -> HashSet<url::Url> {
        const URLS: &[&str] = &[
            "udp://tracker.opentrackr.org:1337/announce",
            "udp://open.stealth.si:80/announce",
            "udp://tracker.torrent.eu.org:451/announce",
            "udp://explodie.org:6969/announce",
            "udp://tracker.internetwarriors.net:1337/announce",
            "udp://tracker.moeking.me:6969/announce",
            "http://tracker.openbittorrent.com:80/announce",
            "http://tracker.opentrackr.org:1337/announce",
        ];
        URLS.iter()
            .filter_map(|u| url::Url::parse(u).ok())
            .collect()
    }

    pub fn set_peer_limit(&self, limit: u32) {
        let clamped = limit.clamp(5, 200) as usize;
        if let Ok(mut inner) = self.inner.lock() {
            inner.peer_limit = clamped;
        }
    }

    pub fn set_disk_cache_capacity_bytes(&self, bytes: u64) {
        let clamped = clamp_capacity_bytes(bytes);
        if let Ok(mut inner) = self.inner.lock() {
            inner.disk_cache_capacity_bytes = clamped;
        }
        let _ = self.reclaim_disk_cache(clamped);
    }

    pub fn disk_cache_capacity_bytes(&self) -> u64 {
        self.inner
            .lock()
            .map(|i| i.disk_cache_capacity_bytes)
            .unwrap_or(DEFAULT_DISK_CACHE_BYTES)
    }

    /// Evict idle cached files until [used] <= [target_bytes]. `u64::MAX` uses the budget.
    pub fn reclaim_disk_cache(&self, target_bytes: u64) -> DiskCacheStats {
        let (capacity, protected) = match self.inner.lock() {
            Ok(inner) => (
                inner.disk_cache_capacity_bytes,
                self.protected_relpaths_locked(&inner),
            ),
            Err(_) => (DEFAULT_DISK_CACHE_BYTES, HashSet::new()),
        };
        let target = if target_bytes == u64::MAX {
            capacity
        } else {
            target_bytes
        };
        disk_cache::reclaim_download_dir(
            &Self::download_dir(),
            &protected,
            target,
            capacity,
        )
        .unwrap_or_else(|_| DiskCacheStats {
            capacity_bytes: capacity,
            ..DiskCacheStats::default()
        })
    }

    pub fn reclaim_disk_cache_json(&self, target_bytes: u64) -> String {
        serde_json::to_string(&self.reclaim_disk_cache(target_bytes)).unwrap_or_else(|_| {
            r#"{"capacity_bytes":0,"used_bytes":0,"protected_bytes":0,"evictions":0,"reclaimed_bytes":0,"over_budget":false}"#.into()
        })
    }

    fn protected_relpaths_locked(&self, inner: &EngineInner) -> HashSet<String> {
        let Some(active) = inner.active.as_ref() else {
            return HashSet::new();
        };
        let Some(api) = inner.api.as_ref() else {
            return HashSet::new();
        };
        let Ok(details) = api.api_torrent_details(TorrentIdOrHash::Id(active.id)) else {
            return HashSet::new();
        };
        details
            .files
            .unwrap_or_default()
            .into_iter()
            .map(|f| f.name.replace('\\', "/"))
            .filter(|name| !name.is_empty() && !name.contains(".."))
            .collect()
    }

    async fn delete_torrent_files(api: &Api, id: usize) {
        let _ = api
            .api_torrent_action_delete(TorrentIdOrHash::Id(id))
            .await;
    }

    pub fn start_engine(&self, preferred_port: u16) -> Result<u16, String> {
        self.runtime.block_on(async {
            let peer_limit = {
                let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
                if inner.http_port > 0 {
                    return Ok(inner.http_port);
                }
                inner.peer_limit
            };
            std::fs::create_dir_all(Self::download_dir()).map_err(|e| e.to_string())?;
            let session = Session::new_with_opts(
                Self::download_dir(),
                Self::session_options(peer_limit),
            )
                .await
                .map_err(|e| e.to_string())?;
            let api = Api::new(session.clone(), None);
            let app = torrent_stream_router(TorrentAppState {
                api: api.clone(),
            });
            let addr = SocketAddr::from(([127, 0, 0, 1], preferred_port));
            // SO_REUSEADDR so restart after stop does not lose the HTTP port to TIME_WAIT.
            let socket = TcpSocket::new_v4().map_err(|e| e.to_string())?;
            socket.set_reuseaddr(true).map_err(|e| e.to_string())?;
            socket.bind(addr).map_err(|e| e.to_string())?;
            let listener = socket.listen(128).map_err(|e| e.to_string())?;
            let port = listener.local_addr().map_err(|e| e.to_string())?.port();
            let (tx, rx) = oneshot::channel();
            tokio::spawn(async move {
                axum::serve(listener, app)
                    .with_graceful_shutdown(async {
                        let _ = rx.await;
                    })
                    .await
                    .ok();
            });
            let mut inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            inner.session = Some(session);
            inner.api = Some(api);
            inner.http_port = port;
            inner.http_shutdown = Some(tx);
            Ok(port)
        })
    }

    pub fn engine_port(&self) -> u16 {
        self.inner.lock().map(|i| i.http_port).unwrap_or(0)
    }

    pub fn torrent_api(&self) -> Option<Api> {
        self.inner.lock().ok().and_then(|i| i.api.clone())
    }

    pub fn stop_engine(&self) {
        self.runtime.block_on(async {
            self.stop_async().await;
            let Ok(mut inner) = self.inner.lock() else {
                return;
            };
            inner.active = None;
            if let Some(tx) = inner.http_shutdown.take() {
                let _ = tx.send(());
            }
            inner.api = None;
            inner.session = None;
            inner.http_port = 0;
        });
        let _ = self.reclaim_disk_cache(u64::MAX);
    }

    pub fn list_files_json(&self, magnet: &str) -> String {
        if magnet.is_empty() || !magnet.starts_with("magnet:") {
            return serde_json::to_string(&StreamError {
                error: "Invalid magnet link".into(),
            })
            .unwrap_or_else(|_| r#"{"error":"Invalid magnet link"}"#.into());
        }
        match self.runtime.block_on(async { self.list_files(magnet).await }) {
            Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into()),
            Err(e) => {
                let msg = e.clone();
                serde_json::to_string(&StreamError { error: e }).unwrap_or_else(|_| {
                    format!(r#"{{"error":"{}"}}"#, msg.replace('"', "\\\""))
                })
            }
        }
    }

    pub fn stream_magnet_json(
        &self,
        magnet: &str,
        season: Option<i32>,
        episode: Option<i32>,
        preferred_idx: Option<i32>,
    ) -> String {
        if magnet.is_empty() || !magnet.starts_with("magnet:") {
            return serde_json::to_string(&StreamError {
                error: "Invalid magnet link".into(),
            })
            .unwrap_or_else(|_| r#"{"error":"Invalid magnet link"}"#.into());
        }
        match self.runtime.block_on(async {
            self.stream_magnet(magnet, season, episode, preferred_idx)
                .await
        }) {
            Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into()),
            Err(e) => {
                let msg = e.clone();
                serde_json::to_string(&StreamError { error: e }).unwrap_or_else(|_| {
                    format!(r#"{{"error":"{}"}}"#, msg.replace('"', "\\\""))
                })
            }
        }
    }

    /// Resolve a magnet on this engine's Tokio runtime.
    ///
    /// Safe to `.await` from another runtime (LAN axum / FFI). Calling
    /// [`stream_magnet_json`] from an async worker nests `Runtime::block_on`
    /// and panics.
    pub async fn stream_magnet_on_engine(
        self: &Arc<Self>,
        magnet: String,
        season: Option<i32>,
        episode: Option<i32>,
        preferred_idx: Option<i32>,
    ) -> Result<StreamResponse, String> {
        if magnet.is_empty() || !magnet.starts_with("magnet:") {
            return Err("Invalid magnet link".into());
        }
        let this = Arc::clone(self);
        self.runtime
            .spawn(async move {
                this.stream_magnet(&magnet, season, episode, preferred_idx)
                    .await
            })
            .await
            .map_err(|e| format!("torrent task failed: {e}"))?
    }

    async fn list_files(&self, magnet: &str) -> Result<ListFilesResponse, String> {
        let prepared = self.prepare_magnet(magnet).await?;
        let files = prepared
            .files
            .iter()
            .enumerate()
            .map(|(index, f)| TorrentFileEntry {
                index,
                name: f.name.clone(),
                size: f.length,
            })
            .collect();
        Ok(ListFilesResponse {
            torrent_id: prepared.torrent_id,
            info_hash: prepared.info_hash,
            files,
        })
    }

    async fn stream_magnet(
        &self,
        magnet: &str,
        season: Option<i32>,
        episode: Option<i32>,
        preferred_idx: Option<i32>,
    ) -> Result<StreamResponse, String> {
        let port = {
            let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            if inner.http_port == 0 {
                return Err("Torrent engine not started".into());
            }
            inner.http_port
        };

        // Keep the current swarm while the new magnet resolves so the player
        // can keep reading its localhost URL (background switch UX).
        let previous = {
            let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            match (
                inner.active.clone(),
                extract_info_hash(magnet).map(|h| h.to_ascii_lowercase()),
            ) {
                (Some(active), Some(h)) if active.info_hash.eq_ignore_ascii_case(&h) => None,
                (Some(active), _) => Some(active),
                _ => None,
            }
        };

        let prepared = self.prepare_magnet(magnet).await?;
        let api = {
            let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            inner.api.clone().ok_or("Torrent engine not started")?
        };

        let file_idx = match select_file_index(
            &prepared.files,
            season,
            episode,
            preferred_idx.map(|v| v as usize),
        ) {
            Some(idx) => idx,
            None => {
                self.restore_active_after_failed_switch(
                    &api,
                    prepared.torrent_id,
                    previous,
                )
                .await;
                return Err("No suitable video file found".into());
            }
        };

        // Download only the selected file — otherwise peers fill random pieces
        // and the stream head stays empty while mpv probes.
        let only_files = HashSet::from([file_idx]);
        if let Err(e) = api
            .api_torrent_action_update_only_files(
                TorrentIdOrHash::Id(prepared.torrent_id),
                &only_files,
            )
            .await
        {
            self.restore_active_after_failed_switch(&api, prepared.torrent_id, previous)
                .await;
            return Err(e.to_string());
        }

        // Block until the first bytes of the file are actually available.
        // Returning the URL at metadata-ready lets mpv open an empty stream
        // and die with "Failed to recognize file format".
        if let Err(e) = wait_for_stream_head(
            &api,
            prepared.torrent_id,
            file_idx,
            STREAM_HEAD_BYTES,
            STREAM_HEAD_TIMEOUT,
        )
        .await
        {
            self.restore_active_after_failed_switch(&api, prepared.torrent_id, previous)
                .await;
            return Err(e);
        }

        // New stream is ready — drop the previous swarm (player will replace).
        if let Some(prev) = previous {
            Self::delete_torrent_files(&api, prev.id).await;
        }

        let file_name = prepared
            .files
            .get(file_idx)
            .map(|f| f.name.as_str())
            .unwrap_or("file");
        let encoded_name = urlencoding::encode(file_name);
        let url = format!(
            "http://127.0.0.1:{port}/torrents/{}/stream/{file_idx}/{encoded_name}",
            prepared.torrent_id
        );

        self.reclaim_disk_cache(u64::MAX);

        if let Ok(mut inner) = self.inner.lock() {
            if let Some(active) = inner.active.as_mut() {
                if active.id == prepared.torrent_id {
                    active.file_idx = file_idx;
                }
            }
        }

        Ok(StreamResponse {
            url,
            torrent_id: prepared.torrent_id,
            file_idx,
            info_hash: prepared.info_hash,
        })
    }

    /// Background read at [byte_offset] — librqbit piece priority for scrub/hover prefetch.
    pub async fn prefetch_file_position_async(&self, byte_offset: u64) -> Result<(), String> {
        let (api, torrent_id, file_idx, prev) = {
            let mut inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            let Some(active) = inner.active.as_ref() else {
                return Err("No active torrent".into());
            };
            let torrent_id = active.id;
            let file_idx = active.file_idx;
            let prev = inner.prefetch_task.take();
            (
                inner.api.clone().ok_or("Torrent engine not started")?,
                torrent_id,
                file_idx,
                prev,
            )
        };
        if let Some(h) = prev {
            h.abort();
        }

        let mut stream = api
            .api_stream(TorrentIdOrHash::Id(torrent_id), file_idx)
            .await
            .map_err(|e| e.to_string())?;
        let len = stream.len();
        if byte_offset >= len {
            return Ok(());
        }
        stream
            .seek(std::io::SeekFrom::Start(byte_offset))
            .await
            .map_err(|e| e.to_string())?;

        let handle = tokio::spawn(async move {
            let mut buf = vec![0u8; 64 * 1024];
            loop {
                match stream.read(&mut buf).await {
                    Ok(0) | Err(_) => break,
                    Ok(_) => {}
                }
            }
        });

        if let Ok(mut inner) = self.inner.lock() {
            inner.prefetch_task = Some(handle);
        }
        Ok(())
    }

    /// Fire-and-forget prefetch from FFI (spawns on this engine's runtime).
    pub fn prefetch_file_position(self: &Arc<Self>, byte_offset: u64) {
        let this = Arc::clone(self);
        let _ = self.runtime.spawn(async move {
            if let Err(e) = this.prefetch_file_position_async(byte_offset).await {
                eprintln!("[torrent] prefetch failed: {e}");
            }
        });
    }

    fn abort_prefetch_locked(inner: &mut EngineInner) {
        if let Some(h) = inner.prefetch_task.take() {
            h.abort();
        }
    }

    async fn prepare_magnet(&self, magnet: &str) -> Result<PreparedTorrent, String> {
        let expected_hash = extract_info_hash(magnet)
            .filter(|hash| hash.len() == 40)
            .map(|hash| hash.to_ascii_lowercase());
        let mut cache_error = None;

        if let Some(hash) = expected_hash.as_deref() {
            let cache_url = metadata_cache_url(hash);
            match self
                .prepare_add(
                    AddTorrent::from_url(&cache_url),
                    METADATA_CACHE_TIMEOUT,
                    format!(
                        "Timed out fetching cached torrent metadata ({}s)",
                        METADATA_CACHE_TIMEOUT.as_secs()
                    ),
                    Some(hash),
                )
                .await
            {
                Ok(prepared) => return Ok(prepared),
                Err(error) => cache_error = Some(error),
            }
        }

        let magnet_result = self
            .prepare_add(
                AddTorrent::from_url(magnet),
                MAGNET_ADD_TIMEOUT,
                format!(
                    "Timed out resolving magnet (no metadata/peers in {}s)",
                    MAGNET_ADD_TIMEOUT.as_secs()
                ),
                expected_hash.as_deref(),
            )
            .await;
        match (magnet_result, cache_error) {
            (Err(magnet_error), Some(cache_error)) => Err(format!(
                "{magnet_error}; metadata cache fallback failed: {cache_error}"
            )),
            (result, _) => result,
        }
    }

    #[cfg(test)]
    async fn prepare_torrent_bytes(&self, bytes: Vec<u8>) -> Result<PreparedTorrent, String> {
        self.prepare_add(
            AddTorrent::from_bytes(bytes),
            TORRENT_INIT_TIMEOUT,
            format!(
                "Timed out adding torrent file ({}s)",
                TORRENT_INIT_TIMEOUT.as_secs()
            ),
            None,
        )
        .await
    }

    /// Adds a magnet/torrent without forgetting the previous swarm.
    ///
    /// Mid-playback switches keep the old HTTP stream alive until
    /// [Self::stream_magnet] confirms the new file head, then drops the
    /// previous id. Forgetting early freezes mpv on a dead localhost URL.
    async fn prepare_add(
        &self,
        add: AddTorrent<'_>,
        add_timeout: Duration,
        add_timeout_msg: String,
        expected_info_hash: Option<&str>,
    ) -> Result<PreparedTorrent, String> {
        let api = {
            let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            if inner.http_port == 0 || inner.api.is_none() {
                return Err("Torrent engine not started".into());
            }
            inner.api.clone().unwrap()
        };

        let session = {
            let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            inner.session.clone().ok_or("Torrent engine not started")?
        };

        let add_opts = AddTorrentOptions {
            overwrite: true,
            trackers: Some(
                Self::default_public_trackers()
                    .into_iter()
                    .map(|u| u.to_string())
                    .collect(),
            ),
            ..Default::default()
        };
        if utils::engine_cancel::is_requested() {
            return Err(utils::engine_cancel::cancelled_message());
        }
        let response = utils::engine_cancel::with_cancel(async {
            tokio::time::timeout(add_timeout, session.add_torrent(add, Some(add_opts)))
                .await
                .map_err(|_| add_timeout_msg.clone())?
                .map_err(|e| e.to_string())
        })
        .await?;

        let handle = match response {
            AddTorrentResponse::Added(_, handle) => handle,
            AddTorrentResponse::AlreadyManaged(_, handle) => handle,
            AddTorrentResponse::ListOnly(_) => {
                return Err("Torrent resolved as list-only".into());
            }
        };

        if utils::engine_cancel::is_requested() {
            return Err(utils::engine_cancel::cancelled_message());
        }
        utils::engine_cancel::with_cancel(async {
            tokio::time::timeout(TORRENT_INIT_TIMEOUT, handle.wait_until_initialized())
                .await
                .map_err(|_| {
                    format!(
                        "Timed out initializing torrent storage ({}s)",
                        TORRENT_INIT_TIMEOUT.as_secs()
                    )
                })?
                .map_err(|e| e.to_string())
        })
        .await?;

        let torrent_id = handle.id();
        let details = api
            .api_torrent_details(TorrentIdOrHash::Id(torrent_id))
            .map_err(|e| e.to_string())?;
        if let Some(expected) = expected_info_hash.filter(|expected| {
            !details.info_hash.eq_ignore_ascii_case(expected)
        }) {
            Self::delete_torrent_files(&api, torrent_id).await;
            return Err(format!(
                "Torrent metadata info hash mismatch (expected {expected}, got {})",
                details.info_hash
            ));
        }
        let files = details.files.ok_or("No files in torrent")?;

        {
            let mut inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            inner.active = Some(ActiveTorrent {
                id: torrent_id,
                info_hash: details.info_hash.clone(),
                file_idx: 0,
            });
        }

        Ok(PreparedTorrent {
            torrent_id,
            info_hash: details.info_hash,
            files,
        })
    }

    async fn restore_active_after_failed_switch(
        &self,
        api: &Api,
        failed_id: usize,
        previous: Option<ActiveTorrent>,
    ) {
        Self::delete_torrent_files(api, failed_id).await;
        if let Ok(mut inner) = self.inner.lock() {
            inner.active = previous;
        }
    }

    pub fn start(&self, magnet: &str) -> Result<(), String> {
        if magnet.is_empty() || !magnet.starts_with("magnet:") {
            return Err("Invalid magnet link".into());
        }
        self.runtime.block_on(async {
            if self.engine_port() == 0 {
                self.start_engine(0)?;
            }
            let _ = self.stream_magnet(magnet, None, None, None).await?;
            Ok(())
        })
    }

    pub fn stop(&self) {
        self.runtime.block_on(async {
            self.stop_async().await;
        });
    }

    /// Delete the active swarm and its files. Safe to call from this engine's runtime.
    async fn stop_async(&self) {
        let delete = {
            let Ok(mut inner) = self.inner.lock() else {
                return;
            };
            Self::abort_prefetch_locked(&mut inner);
            match (inner.api.clone(), inner.active.take()) {
                (Some(api), Some(active)) => Some((api, active.id)),
                _ => None,
            }
        };
        if let Some((api, id)) = delete {
            Self::delete_torrent_files(&api, id).await;
        }
        self.reclaim_disk_cache(u64::MAX);
    }

    /// Pause the active swarm but keep it tracked (idle TV — may resume).
    async fn pause_active_async(&self) {
        let pause = {
            let Ok(inner) = self.inner.lock() else {
                return;
            };
            let (Some(session), Some(active)) = (inner.session.clone(), inner.active.clone())
            else {
                return;
            };
            session
                .get(TorrentIdOrHash::Id(active.id))
                .map(|handle| (session, handle))
        };
        if let Some((session, handle)) = pause {
            let _ = session.pause(&handle).await;
        }
    }

    /// Resume a previously paused active swarm.
    async fn unpause_active_async(&self) {
        let unpause = {
            let Ok(inner) = self.inner.lock() else {
                return;
            };
            let (Some(session), Some(active)) = (inner.session.clone(), inner.active.clone())
            else {
                return;
            };
            session
                .get(TorrentIdOrHash::Id(active.id))
                .map(|handle| (session, handle))
        };
        if let Some((session, handle)) = unpause {
            let _ = session.unpause(&handle).await;
        }
    }

    /// Stop the active swarm from another Tokio runtime (LAN axum / FFI).
    ///
    /// Same pattern as [`stream_magnet_on_engine`] — never `block_on` this
    /// engine's runtime from inside the LAN worker (nested runtime panic).
    pub async fn stop_on_engine(self: &Arc<Self>) {
        let this = Arc::clone(self);
        let _ = self
            .runtime
            .spawn(async move {
                this.stop_async().await;
            })
            .await;
    }

    /// Pause (keep active) from another Tokio runtime.
    pub async fn pause_active_on_engine(self: &Arc<Self>) {
        let this = Arc::clone(self);
        let _ = self
            .runtime
            .spawn(async move {
                this.pause_active_async().await;
            })
            .await;
    }

    /// Unpause from another Tokio runtime.
    pub async fn unpause_active_on_engine(self: &Arc<Self>) {
        let this = Arc::clone(self);
        let _ = self
            .runtime
            .spawn(async move {
                this.unpause_active_async().await;
            })
            .await;
    }

    pub fn is_running(&self) -> bool {
        let Ok(inner) = self.inner.lock() else {
            return false;
        };
        let Some(active) = inner.active.as_ref() else {
            return false;
        };
        let Some(session) = inner.session.as_ref() else {
            return false;
        };
        session
            .get(TorrentIdOrHash::Id(active.id))
            .map(|handle| {
                let stats = handle.stats();
                !stats.finished && stats.error.is_none()
            })
            .unwrap_or(false)
    }

    pub fn status(&self) -> Option<TorrentStatus> {
        let inner = self.inner.lock().ok()?;
        let active = inner.active.as_ref()?;
        let session = inner.session.as_ref()?;
        let handle = session.get(TorrentIdOrHash::Id(active.id))?;
        let stats = handle.stats();
        let name = handle
            .name()
            .or_else(|| Some(active.info_hash.clone()))
            .unwrap_or_default();
        let progress = if stats.total_bytes == 0 {
            0.0
        } else {
            stats.progress_bytes as f64 / stats.total_bytes as f64
        };
        let (download_rate, upload_rate, num_peers, num_seen, eta_secs) =
            if let Some(live) = stats.live.as_ref() {
                let eta_secs = handle
                    .live()
                    .and_then(|l| l.down_speed_estimator().time_remaining())
                    .map(|d| d.as_secs())
                    .unwrap_or(0);
                (
                    live.download_speed.as_bytes(),
                    live.upload_speed.as_bytes(),
                    live.snapshot.peer_stats.live,
                    live.snapshot.peer_stats.seen,
                    eta_secs,
                )
            } else {
                (0, 0, 0, 0, 0)
            };
        let state = if stats.finished {
            "seeding".into()
        } else if stats.progress_bytes > 0 {
            "downloading".into()
        } else {
            format!("{}", stats.state)
        };
        Some(TorrentStatus {
            name,
            info_hash: active.info_hash.clone(),
            progress,
            download_rate,
            upload_rate,
            num_peers,
            num_seen,
            progress_bytes: stats.progress_bytes,
            total_bytes: stats.total_bytes,
            eta_secs,
            state,
        })
    }

    /// librqbit download root (`{temp}/torrent`).
    pub fn cache_dir() -> PathBuf {
        Self::download_dir()
    }

    /// Delete one cached media file under the download root (no path traversal).
    pub fn delete_cached_named(file_name: &str) -> Result<bool, String> {
        if file_name.is_empty()
            || file_name.contains("..")
            || file_name.contains('/')
            || file_name.contains('\\')
        {
            return Err("invalid cache file name".into());
        }
        let path = Self::download_dir().join(file_name);
        if !path.exists() {
            return Ok(false);
        }
        std::fs::remove_file(&path).map_err(|e| e.to_string())?;
        Ok(true)
    }

    /// Wipe the torrent download directory (including DHT state).
    pub fn clear_cache_dir() -> Result<(), String> {
        let dir = Self::download_dir();
        if !dir.exists() {
            return Ok(());
        }
        std::fs::remove_dir_all(&dir).map_err(|e| e.to_string())
    }

    /// Session torrent progress + on-disk bytes under [`Self::download_dir`].
    pub fn download_cache_snapshot(&self) -> DownloadCacheSnapshot {
        let cache_dir = Self::download_dir();
        let disk_bytes = disk_cache::directory_bytes(&cache_dir);
        let mut progress_bytes = 0u64;
        let mut total_bytes = 0u64;
        let mut torrent_count = 0u32;
        if let Ok(inner) = self.inner.lock() {
            if let (Some(api), Some(session)) = (inner.api.as_ref(), inner.session.as_ref()) {
                for torrent in api.api_torrent_list().torrents {
                    torrent_count += 1;
                    let Some(id) = torrent.id else {
                        continue;
                    };
                    let Some(handle) = session.get(TorrentIdOrHash::Id(id)) else {
                        continue;
                    };
                    let stats = handle.stats();
                    progress_bytes = progress_bytes.saturating_add(stats.progress_bytes);
                    total_bytes = total_bytes.saturating_add(stats.total_bytes);
                }
            }
        }
        let active = torrent_count > 0
            && (progress_bytes > 0 || total_bytes > 0)
            && progress_bytes < total_bytes.max(1);
        DownloadCacheSnapshot {
            cache_dir: cache_dir.to_string_lossy().into_owned(),
            disk_bytes,
            progress_bytes,
            total_bytes,
            torrent_count,
            active,
        }
    }

    pub fn download_cache_snapshot_json(&self) -> String {
        serde_json::to_string(&self.download_cache_snapshot()).unwrap_or_else(|_| {
            r#"{"cache_dir":"","disk_bytes":0,"progress_bytes":0,"total_bytes":0,"torrent_count":0,"active":false}"#.into()
        })
    }

    /// Stop every swarm in the session and wipe the download directory.
    pub fn clear_all_downloads(&self) -> DownloadCacheSnapshot {
        self.runtime.block_on(async { self.clear_all_downloads_async().await })
    }

    pub fn clear_all_downloads_json(&self) -> String {
        serde_json::to_string(&self.clear_all_downloads()).unwrap_or_else(|_| {
            r#"{"cache_dir":"","disk_bytes":0,"progress_bytes":0,"total_bytes":0,"torrent_count":0,"active":false}"#.into()
        })
    }

    async fn clear_all_downloads_async(&self) -> DownloadCacheSnapshot {
        let api = {
            let Ok(inner) = self.inner.lock() else {
                let _ = Self::clear_cache_dir();
                return self.download_cache_snapshot();
            };
            inner.api.clone()
        };
        if let Some(api) = api {
            let ids: Vec<usize> = api
                .api_torrent_list()
                .torrents
                .into_iter()
                .filter_map(|t| t.id)
                .collect();
            for id in ids {
                Self::delete_torrent_files(&api, id).await;
            }
        }
        if let Ok(mut inner) = self.inner.lock() {
            inner.active = None;
        }
        let _ = self.reclaim_disk_cache(0);
        let _ = Self::clear_cache_dir();
        self.download_cache_snapshot()
    }

    pub fn status_json(&self) -> String {
        match self.status() {
            Some(s) => serde_json::to_string(&s).unwrap_or_else(|_| "{}".into()),
            None => "null".into(),
        }
    }
}

/// Opens a librqbit file stream (registers piece priority) and reads until
/// [min_bytes] arrive or [timeout] elapses. Dropping the stream keeps the
/// downloaded head on disk for the subsequent HTTP open from mpv.
///
/// On timeout: still succeed if we got [STREAM_HEAD_MIN_ACCEPT] — matches
/// desktop clients that open playback once *some* head exists and keep
/// buffering. Hard-fail only when the head is still empty.
async fn wait_for_stream_head(
    api: &Api,
    torrent_id: usize,
    file_idx: usize,
    min_bytes: u64,
    timeout: Duration,
) -> Result<(), String> {
    let mut stream = api
        .api_stream(TorrentIdOrHash::Id(torrent_id), file_idx)
        .await
        .map_err(|e| e.to_string())?;
    let need = min_bytes.min(stream.len()).max(1) as usize;
    let min_accept = (STREAM_HEAD_MIN_ACCEPT as usize).min(need);
    let mut buf = vec![0u8; need];
    let mut read = 0usize;

    let timed_out = utils::engine_cancel::with_cancel(async {
        tokio::time::timeout(timeout, async {
            while read < need {
                if utils::engine_cancel::is_requested() {
                    return Err(utils::engine_cancel::cancelled_message());
                }
                let n = stream
                    .read(&mut buf[read..])
                    .await
                    .map_err(|e| e.to_string())?;
                if n == 0 {
                    break;
                }
                read += n;
            }
            Ok::<(), String>(())
        })
        .await
        .map_err(|_| "head_timeout".to_string())?
    })
    .await;

    match timed_out {
        Ok(()) => {}
        Err(e) if e == utils::engine_cancel::cancelled_message() => return Err(e),
        Err(e) if e == "head_timeout" => {
            if read >= min_accept {
                // Partial head — hand URL to mpv; HTTP stream continues pull.
                return Ok(());
            }
            let (peers, seen, progress) = peer_snapshot(api, torrent_id);
            return Err(format!(
                "Timed out waiting for torrent stream head \
                 (got {read}/{need} bytes, peers={peers}/{seen}, progress={progress}B)"
            ));
        }
        Err(e) => return Err(e),
    }

    if read == 0 {
        let (peers, seen, progress) = peer_snapshot(api, torrent_id);
        return Err(format!(
            "Torrent stream head empty (peers={peers}/{seen}, progress={progress}B)"
        ));
    }
    Ok(())
}

fn peer_snapshot(api: &Api, torrent_id: usize) -> (u32, u32, u64) {
    let Ok(stats) = api.api_stats_v1(TorrentIdOrHash::Id(torrent_id)) else {
        return (0, 0, 0);
    };
    let progress = stats.progress_bytes;
    let (live, seen) = stats
        .live
        .as_ref()
        .map(|l| (l.snapshot.peer_stats.live, l.snapshot.peer_stats.seen))
        .unwrap_or((0, 0));
    (live, seen, progress)
}

/// Shared torrent HTTP stream routes for loopback engine and LAN remount.
pub fn torrent_stream_router(state: TorrentAppState) -> Router {
    Router::new()
        .route(
            "/torrents/{id}/stream/{file_id}/{*filename}",
            get(stream_file_handler),
        )
        .with_state(state)
}

async fn stream_file_handler(
    State(state): State<TorrentAppState>,
    Path((id, file_id, _filename)): Path<(usize, usize, String)>,
    headers: HeaderMap,
) -> Result<Response, StatusCode> {
    let mut stream = state
        .api
        .api_stream(TorrentIdOrHash::Id(id), file_id)
        .await
        .map_err(|_| StatusCode::NOT_FOUND)?;

    let mut status = StatusCode::OK;
    let mut output_headers = HeaderMap::new();
    output_headers.insert(header::ACCEPT_RANGES, "bytes".parse().unwrap());

    if let Ok(mime) = state
        .api
        .torrent_file_mime_type(TorrentIdOrHash::Id(id), file_id)
    {
        output_headers.insert(header::CONTENT_TYPE, mime.parse().unwrap());
    }

    let range = headers
        .get(header::RANGE)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("bytes="))
        .and_then(|v| v.split_once('-'))
        .and_then(|(start, end)| {
            let start = start.parse::<u64>().ok()?;
            let end = if end.is_empty() {
                None
            } else {
                Some(end.parse::<u64>().ok()?.saturating_add(1))
            };
            Some((start, end))
        });

    let reader: Box<dyn AsyncRead + Send + Unpin> = if let Some((start, end)) = range {
        status = StatusCode::PARTIAL_CONTENT;
        if start >= stream.len() || end.is_some_and(|end| end <= start || end > stream.len()) {
            return Err(StatusCode::RANGE_NOT_SATISFIABLE);
        }
        let end = end.unwrap_or(stream.len());
        stream
            .seek(std::io::SeekFrom::Start(start))
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        let to_take = end - start;
        output_headers.insert(
            header::CONTENT_LENGTH,
            to_take.to_string().parse().unwrap(),
        );
        output_headers.insert(
            header::CONTENT_RANGE,
            format!(
                "bytes {}-{}/{}",
                start,
                end.saturating_sub(1),
                stream.len()
            )
            .parse()
            .unwrap(),
        );
        Box::new(stream.take(to_take))
    } else {
        output_headers.insert(
            header::CONTENT_LENGTH,
            stream.len().to_string().parse().unwrap(),
        );
        Box::new(stream)
    };

    let body_stream = ReaderStream::with_capacity(reader, 65536)
        .map_err(std::io::Error::other);
    Response::builder()
        .status(status)
        .body(Body::from_stream(body_stream))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

fn extract_info_hash(magnet: &str) -> Option<String> {
    let lower = magnet.to_ascii_lowercase();
    let xt = lower.split("xt=urn:btih:").nth(1)?;
    let hash = xt.split('&').next()?;
    if hash.is_empty() {
        return None;
    }
    Some(hash.to_string())
}

fn metadata_cache_url(info_hash: &str) -> String {
    format!(
        "{METADATA_CACHE_BASE_URL}/{}.torrent",
        info_hash.to_ascii_uppercase()
    )
}

fn pick_largest(files: &[TorrentDetailsResponseFile], indices: &[usize]) -> usize {
    indices
        .iter()
        .copied()
        .max_by_key(|&i| files.get(i).map(|f| f.length).unwrap_or(0))
        .unwrap_or(indices[0])
}

fn select_file_index(
    files: &[TorrentDetailsResponseFile],
    season: Option<i32>,
    episode: Option<i32>,
    preferred_idx: Option<usize>,
) -> Option<usize> {
    let file_names: Vec<String> = files.iter().map(|f| f.name.clone()).collect();

    // Stremio/Torrentio `fileIdx` is authoritative when present.
    if let Some(idx) = preferred_idx {
        if idx < files.len() && torrent_filter::is_video_file(&files[idx].name) {
            return Some(idx);
        }
    }

    if let (Some(s), Some(e)) = (season, episode) {
        let matches: Vec<usize> = file_names
            .iter()
            .enumerate()
            .filter(|(_, name)| {
                torrent_filter::is_video_file(name) && episode_matcher::matches(name, s, e)
            })
            .map(|(i, _)| i)
            .collect();
        if !matches.is_empty() {
            return Some(pick_largest(files, &matches));
        }
    }

    if let (Some(s), Some(e)) = (season, episode) {
        if let Some(idx) = episode_matcher::pick_episode_index(&file_names, s, e) {
            return Some(idx);
        }
    }

    let mut videos: Vec<(usize, u64)> = files
        .iter()
        .enumerate()
        .filter(|(_, f)| f.included && torrent_filter::is_video_file(&f.name))
        .map(|(i, f)| (i, f.length))
        .collect();
    if videos.is_empty() {
        videos = files
            .iter()
            .enumerate()
            .filter(|(_, f)| f.included && f.length > 0)
            .map(|(i, f)| (i, f.length))
            .collect();
    }
    if videos.is_empty() {
        return None;
    }
    videos.sort_by_key(|(_, len)| std::cmp::Reverse(*len));
    Some(videos[0].0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_invalid_magnet() {
        let engine = TorrentEngine::new();
        assert!(engine.start("http://example.com").is_err());
    }

    #[test]
    fn status_none_when_idle() {
        let engine = TorrentEngine::new();
        assert!(engine.status().is_none());
        assert!(!engine.is_running());
    }

    #[test]
    fn set_peer_limit_clamps() {
        let engine = TorrentEngine::new();
        engine.set_peer_limit(999);
        engine.set_peer_limit(1);
    }

    #[test]
    fn disk_cache_capacity_clamps_and_reclaim_json() {
        let engine = TorrentEngine::new();
        engine.set_disk_cache_capacity_bytes(1);
        assert_eq!(
            engine.disk_cache_capacity_bytes(),
            disk_cache::MIN_DISK_CACHE_BYTES
        );
        let json = engine.reclaim_disk_cache_json(u64::MAX);
        let v: serde_json::Value = serde_json::from_str(&json).expect("json");
        assert_eq!(
            v["capacity_bytes"].as_u64(),
            Some(disk_cache::MIN_DISK_CACHE_BYTES)
        );
    }

    #[test]
    fn extracts_info_hash_from_magnet() {
        let magnet = "magnet:?xt=urn:btih:abc123def456&dn=test";
        assert_eq!(extract_info_hash(magnet).as_deref(), Some("abc123def456"));
    }

    #[test]
    fn builds_uppercase_metadata_cache_url() {
        assert_eq!(
            metadata_cache_url("dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c"),
            "https://itorrents.net/torrent/DD8255ECDC7CA55FB0BBF81323D87062DB1F6D1C.torrent"
        );
    }

    #[test]
    fn engine_starts_on_loopback() {
        let engine = TorrentEngine::new();
        let port = engine.start_engine(0).expect("start_engine");
        assert!(port > 0);
        assert_eq!(engine.engine_port(), port);
        engine.stop_engine();
        assert_eq!(engine.engine_port(), 0);
    }

    /// Live network smoke: info hash → validated cached `.torrent` metadata.
    #[test]
    #[ignore = "network: public torrent metadata cache"]
    fn metadata_cache_resolves_public_torrent() {
        let hash = "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c";
        let engine = TorrentEngine::new();
        engine.start_engine(0).expect("start_engine");
        let result = engine.runtime.block_on(engine.prepare_add(
            AddTorrent::from_url(&metadata_cache_url(hash)),
            METADATA_CACHE_TIMEOUT,
            "metadata cache timeout".into(),
            Some(hash),
        ));
        let prepared = result.unwrap_or_else(|error| panic!("metadata cache failed: {error}"));
        assert_eq!(prepared.info_hash, hash);
        assert!(!prepared.files.is_empty());
        engine.stop_engine();
    }

    /// Live network smoke: public-domain Big Buck Bunny magnet → stream head bytes.
    /// Run: cargo test -p torrent stream_head_from_public_magnet -- --ignored --nocapture
    #[test]
    #[ignore = "network: live magnet swarm"]
    fn stream_head_from_public_magnet() {
        let magnet = "magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c\
&dn=Big+Buck+Bunny\
&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337\
&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce\
&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce";
        let engine = TorrentEngine::new();
        let port = engine.start_engine(0).expect("start_engine");
        assert!(port > 0);
        let json = engine.stream_magnet_json(magnet, None, None, None);
        eprintln!("stream_magnet_json => {json}");
        let v: serde_json::Value = serde_json::from_str(&json).expect("json");
        if let Some(err) = v.get("error") {
            panic!("stream failed: {err}");
        }
        let url = v["url"].as_str().expect("url");
        assert!(url.starts_with("http://127.0.0.1:"), "{url}");
        assert_localhost_range_ok(url);
        engine.stop_engine();
    }

    /// Live network smoke with .torrent metadata already present (skips magnet DHT).
    /// Run: cargo test -p torrent stream_head_from_bbb_torrent_file -- --ignored --nocapture
    #[test]
    #[ignore = "network: live torrent swarm"]
    fn stream_head_from_bbb_torrent_file() {
        let path = "/tmp/bbb.torrent";
        if !std::path::Path::new(path).exists() {
            let status = std::process::Command::new("curl")
                .args([
                    "-sSL",
                    "-o",
                    path,
                    "https://webtorrent.io/torrents/big-buck-bunny.torrent",
                ])
                .status()
                .expect("curl");
            assert!(status.success(), "failed to download {path}");
        }
        let bytes = std::fs::read(path).expect("read torrent");
        let engine = TorrentEngine::new();
        let port = engine.start_engine(0).expect("start_engine");
        assert!(port > 0);

        let url = engine
            .runtime
            .block_on(async {
                let prepared = engine.prepare_torrent_bytes(bytes).await?;
                let file_idx = select_file_index(&prepared.files, None, None, None)
                    .ok_or_else(|| "No suitable video file found".to_string())?;
                let api = {
                    let inner = engine.inner.lock().map_err(|_| "Engine lock poisoned")?;
                    inner.api.clone().ok_or("Torrent engine not started")?
                };
                let only_files = HashSet::from([file_idx]);
                api.api_torrent_action_update_only_files(
                    TorrentIdOrHash::Id(prepared.torrent_id),
                    &only_files,
                )
                .await
                .map_err(|e| e.to_string())?;
                wait_for_stream_head(
                    &api,
                    prepared.torrent_id,
                    file_idx,
                    STREAM_HEAD_BYTES,
                    STREAM_HEAD_TIMEOUT,
                )
                .await?;
                let file_name = prepared
                    .files
                    .get(file_idx)
                    .map(|f| f.name.as_str())
                    .unwrap_or("file");
                let encoded_name = urlencoding::encode(file_name);
                Ok::<String, String>(format!(
                    "http://127.0.0.1:{port}/torrents/{}/stream/{file_idx}/{encoded_name}",
                    prepared.torrent_id
                ))
            })
            .expect("stream from torrent file");

        eprintln!("stream url => {url}");
        assert_localhost_range_ok(&url);
        engine.stop_engine();
    }

    fn assert_localhost_range_ok(url: &str) {
        let out = std::process::Command::new("curl")
            .args([
                "-sS",
                "-D",
                "-",
                "-o",
                "/tmp/forja_torrent_head.bin",
                "-r",
                "0-1023",
                url,
            ])
            .output()
            .expect("curl");
        let headers = String::from_utf8_lossy(&out.stdout);
        eprintln!("http headers =>\n{headers}");
        assert!(
            out.status.success(),
            "curl failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert!(
            headers.contains("200") || headers.contains("206"),
            "unexpected status: {headers}"
        );
        let len = std::fs::metadata("/tmp/forja_torrent_head.bin")
            .expect("head file")
            .len();
        eprintln!("http body len => {len}");
        assert!(len > 0);
    }


}
