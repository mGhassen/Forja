use axum::{
    extract::{Query, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
};
use futures_util::future::join_all;
use regex::Regex;
use serde::Deserialize;
use std::sync::{Arc, LazyLock};
use tokio::sync::Mutex;

use crate::ProxyState;

#[derive(Debug, Deserialize)]
pub struct SubtitlecatQuery {
    pub orig: String,
    pub tl: String,
    pub name: Option<String>,
}

static NUM_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[0-9 \r]*$").unwrap());
static TS_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[0-9,: ]*-->[0-9,: \r]*$").unwrap());
static FONT_OPEN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)<font[^>]*>").unwrap());
static FONT_CLOSE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)</font>").unwrap());

pub async fn subtitlecat_translate_handler(
    State(state): State<ProxyState>,
    Query(query): Query<SubtitlecatQuery>,
) -> Result<Response, StatusCode> {
    if query.orig.is_empty() || query.tl.is_empty() {
        return Ok((
            StatusCode::BAD_REQUEST,
            [(header::CONTENT_TYPE, "text/plain")],
            "Missing orig or tl",
        )
            .into_response());
    }

    let name = query.name.as_deref().unwrap_or("subtitle");

    match translate_srt(&state, &query.orig, &query.tl).await {
        Ok(srt) => {
            let disposition =
                format!("inline; filename=\"{name}-{}.srt\"", query.tl);
            Ok(Response::builder()
                .status(StatusCode::OK)
                .header(header::CONTENT_TYPE, "application/x-subrip; charset=utf-8")
                .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .header(header::CONTENT_DISPOSITION, disposition)
                .body(axum::body::Body::from(srt))
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?)
        }
        Err(e) => Ok((
            StatusCode::INTERNAL_SERVER_ERROR,
            [(header::CONTENT_TYPE, "text/plain")],
            format!("Translation failed: {e}"),
        )
            .into_response()),
    }
}

async fn translate_srt(
    state: &ProxyState,
    orig_url: &str,
    target_lang: &str,
) -> Result<String, String> {
    let resp = state
        .client
        .get(orig_url)
        .header(
            header::USER_AGENT,
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
        )
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        return Err(format!("orig {}", resp.status()));
    }
    let bytes = resp.bytes().await.map_err(|e| e.to_string())?;
    let body = String::from_utf8_lossy(&bytes).into_owned();
    let src_lines: Vec<&str> = body.lines().collect();
    let translated = Arc::new(Mutex::new(vec![String::new(); src_lines.len()]));

    const CHARS_PER_BATCH: usize = 500;
    let mut batches: Vec<String> = Vec::new();
    let mut lines_in_batch: Vec<Vec<usize>> = Vec::new();
    let mut cur_batch = String::new();
    let mut cur_chars = 0usize;
    let mut cur_indices: Vec<usize> = Vec::new();

    for (i, line) in src_lines.iter().enumerate() {
        if NUM_RE.is_match(line) || TS_RE.is_match(line) {
            translated.lock().await[i] = (*line).to_string();
            continue;
        }
        let cleaned = FONT_OPEN.replace_all(line, "").into_owned();
        let cleaned = FONT_CLOSE.replace_all(&cleaned, "").into_owned();
        let cleaned = cleaned.replace('&', "and");

        let cleaned_len = cleaned.len();
        if cur_chars + cleaned_len + 1 < CHARS_PER_BATCH {
            if cur_batch.is_empty() {
                cur_batch = cleaned;
            } else {
                cur_batch.push('\n');
                cur_batch.push_str(&cleaned);
            }
            cur_chars += cleaned_len + 1;
            cur_indices.push(i);
        } else {
            batches.push(std::mem::take(&mut cur_batch));
            lines_in_batch.push(std::mem::take(&mut cur_indices));
            cur_batch = cleaned;
            cur_chars = cur_batch.len() + 1;
            cur_indices.push(i);
        }
    }
    if !cur_indices.is_empty() || !cur_batch.is_empty() {
        batches.push(cur_batch);
        lines_in_batch.push(cur_indices);
    }

    const PARALLEL: usize = 8;
    let next = Arc::new(std::sync::atomic::AtomicUsize::new(0));
    let state = state.clone();
    let target_lang = target_lang.to_string();

    let workers: Vec<_> = (0..PARALLEL.min(batches.len().max(1)))
        .map(|_| {
            let next = Arc::clone(&next);
            let batches = batches.clone();
            let lines_in_batch = lines_in_batch.clone();
            let translated = Arc::clone(&translated);
            let state = state.clone();
            let target_lang = target_lang.clone();
            async move {
                loop {
                    let b = next.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                    if b >= batches.len() {
                        break;
                    }
                    let batch = &batches[b];
                    let indices = &lines_in_batch[b];
                    if indices.is_empty() {
                        continue;
                    }
                    let mut out = translated.lock().await;
                    match translate_batch(&state, batch, &target_lang).await {
                        Ok(lines) if lines.len() == indices.len() => {
                            for (k, idx) in indices.iter().enumerate() {
                                out[*idx] = lines[k].clone();
                            }
                        }
                        Ok(_) => {
                            let orig_pieces: Vec<&str> = batch.split('\n').collect();
                            for (k, idx) in indices.iter().enumerate() {
                                let src = orig_pieces.get(k).copied().unwrap_or("");
                                if src.trim().is_empty() {
                                    out[*idx] = src.to_string();
                                    continue;
                                }
                                out[*idx] = translate_batch(&state, src, &target_lang)
                                    .await
                                    .ok()
                                    .and_then(|v| v.into_iter().next())
                                    .unwrap_or_else(|| src.to_string());
                            }
                        }
                        Err(_) => {
                            let orig_pieces: Vec<&str> = batch.split('\n').collect();
                            for (k, idx) in indices.iter().enumerate() {
                                out[*idx] = orig_pieces.get(k).copied().unwrap_or("").to_string();
                            }
                        }
                    }
                }
            }
        })
        .collect();

    join_all(workers).await;

    let final_lines = translated.lock().await.clone();
    Ok(format!("{}\n", final_lines.join("\n")))
}

async fn translate_batch(state: &ProxyState, text: &str, tl: &str) -> Result<Vec<String>, String> {
    let resp = state
        .client
        .get("https://translate.googleapis.com/translate_a/single")
        .query(&[
            ("client", "gtx"),
            ("sl", "auto"),
            ("tl", tl),
            ("dt", "t"),
            ("q", text),
        ])
        .header(
            header::USER_AGENT,
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
        )
        .header(header::ACCEPT, "*/*")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        return Err(format!("gtx {}", resp.status()));
    }
    let root: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
    let segments = root
        .get(0)
        .and_then(|v| v.as_array())
        .ok_or_else(|| "bad gtx response".to_string())?;
    let mut buf = String::new();
    for seg in segments {
        if let Some(s) = seg.get(0).and_then(|v| v.as_str()) {
            buf.push_str(s);
        }
    }
    Ok(buf.lines().map(|l| l.to_string()).collect())
}
