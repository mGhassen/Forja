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
use librqbit::{AddTorrent, AddTorrentOptions, AddTorrentResponse, Session, SessionOptions};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncSeekExt};
use tokio::sync::oneshot;
use tokio_util::io::ReaderStream;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TorrentStatus {
    pub name: String,
    pub progress: f64,
    pub download_rate: u64,
    pub upload_rate: u64,
    pub num_peers: u32,
    pub state: String,
}

#[derive(Debug, Serialize)]
struct StreamResponse {
    url: String,
    torrent_id: usize,
    file_idx: usize,
    info_hash: String,
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
struct AppState {
    api: Api,
}

#[derive(Clone)]
struct ActiveTorrent {
    id: usize,
    info_hash: String,
}

struct EngineInner {
    session: Option<Arc<Session>>,
    api: Option<Api>,
    http_port: u16,
    http_shutdown: Option<oneshot::Sender<()>>,
    active: Option<ActiveTorrent>,
    peer_limit: usize,
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
            }),
            runtime: tokio::runtime::Runtime::new().expect("tokio runtime"),
        }
    }

    fn download_dir() -> PathBuf {
        std::env::temp_dir().join("torrent")
    }

    pub fn set_peer_limit(&self, limit: u32) {
        let clamped = limit.clamp(5, 200) as usize;
        if let Ok(mut inner) = self.inner.lock() {
            inner.peer_limit = clamped;
        }
    }

    pub fn start_engine(&self, preferred_port: u16) -> Result<u16, String> {
        self.runtime.block_on(async {
            let mut inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            if inner.http_port > 0 {
                return Ok(inner.http_port);
            }
            std::fs::create_dir_all(Self::download_dir()).map_err(|e| e.to_string())?;
            let mut opts = SessionOptions::default();
            opts.peer_limit = Some(inner.peer_limit);
            let session = Session::new_with_opts(Self::download_dir(), opts)
                .await
                .map_err(|e| e.to_string())?;
            let api = Api::new(session.clone(), None);
            let app = Router::new()
                .route(
                    "/torrents/{id}/stream/{file_id}/{*filename}",
                    get(stream_file_handler),
                )
                .with_state(AppState {
                    api: api.clone(),
                });
            let addr = SocketAddr::from(([127, 0, 0, 1], preferred_port));
            let listener = tokio::net::TcpListener::bind(addr)
                .await
                .map_err(|e| e.to_string())?;
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

    pub fn stop_engine(&self) {
        let _ = self.runtime.block_on(async {
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

        let prepared = self.prepare_magnet(magnet).await?;
        let file_idx = select_file_index(
            &prepared.files,
            season,
            episode,
            preferred_idx.map(|v| v as usize),
        )
        .ok_or("No suitable video file found")?;
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

        Ok(StreamResponse {
            url,
            torrent_id: prepared.torrent_id,
            file_idx,
            info_hash: prepared.info_hash,
        })
    }

    async fn prepare_magnet(&self, magnet: &str) -> Result<PreparedTorrent, String> {
        let api = {
            let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            if inner.http_port == 0 || inner.api.is_none() {
                return Err("Torrent engine not started".into());
            }
            inner.api.clone().unwrap()
        };

        let new_hash = extract_info_hash(magnet);
        {
            let mut inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            if let Some(active) = inner.active.clone() {
                if new_hash.as_deref() != Some(active.info_hash.as_str()) {
                    let _ = api
                        .api_torrent_action_forget(TorrentIdOrHash::Id(active.id))
                        .await;
                    inner.active = None;
                }
            }
        }

        let session = {
            let inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            inner.session.clone().ok_or("Torrent engine not started")?
        };

        let add_opts = AddTorrentOptions {
            overwrite: true,
            ..Default::default()
        };
        let response = tokio::time::timeout(
            Duration::from_secs(8),
            session.add_torrent(AddTorrent::from_url(magnet), Some(add_opts)),
        )
        .await
        .map_err(|_| "Timed out adding torrent".to_string())?
        .map_err(|e| e.to_string())?;

        let handle = match response {
            AddTorrentResponse::Added(_, handle) => handle,
            AddTorrentResponse::AlreadyManaged(_, handle) => handle,
            AddTorrentResponse::ListOnly(_) => {
                return Err("Magnet resolved as list-only torrent".into());
            }
        };

        tokio::time::timeout(Duration::from_secs(30), handle.wait_until_initialized())
            .await
            .map_err(|_| "Metadata timeout".to_string())?
            .map_err(|e| e.to_string())?;

        let torrent_id = handle.id();
        let details = api
            .api_torrent_details(TorrentIdOrHash::Id(torrent_id))
            .map_err(|e| e.to_string())?;
        let files = details.files.ok_or("No files in torrent")?;

        {
            let mut inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            inner.active = Some(ActiveTorrent {
                id: torrent_id,
                info_hash: details.info_hash.clone(),
            });
        }

        Ok(PreparedTorrent {
            torrent_id,
            info_hash: details.info_hash,
            files,
        })
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
        let _ = self.runtime.block_on(async {
            let Ok(mut inner) = self.inner.lock() else {
                return;
            };
            if let (Some(session), Some(active)) = (inner.session.clone(), inner.active.take()) {
                if let Some(handle) = session.get(TorrentIdOrHash::Id(active.id)) {
                    let _ = session.pause(&handle).await;
                }
            }
        });
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
        let (download_rate, upload_rate, num_peers) = if let Some(live) = stats.live.as_ref() {
            (
                (live.download_speed.mbps * 1_000_000.0) as u64,
                (live.upload_speed.mbps * 1_000_000.0) as u64,
                live.snapshot.peer_stats.live as u32,
            )
        } else {
            (0, stats.uploaded_bytes, 0)
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
            progress,
            download_rate,
            upload_rate,
            num_peers,
            state,
        })
    }

    pub fn status_json(&self) -> String {
        match self.status() {
            Some(s) => serde_json::to_string(&s).unwrap_or_else(|_| "{}".into()),
            None => "null".into(),
        }
    }
}

async fn stream_file_handler(
    State(state): State<AppState>,
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
        .map_err(|e| std::io::Error::other(e));
    Response::builder()
        .status(status)
        .body(Body::from_stream(body_stream))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

fn extract_info_hash(magnet: &str) -> Option<String> {
    let xt = magnet.split("xt=urn:btih:").nth(1)?;
    let hash = xt.split('&').next()?;
    Some(hash.to_lowercase())
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

    if let Some(idx) = preferred_idx {
        if idx < files.len() && torrent_filter::is_video_file(&files[idx].name) {
            return Some(idx);
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
    fn extracts_info_hash_from_magnet() {
        let magnet = "magnet:?xt=urn:btih:abc123def456&dn=test";
        assert_eq!(extract_info_hash(magnet).as_deref(), Some("abc123def456"));
    }
}
