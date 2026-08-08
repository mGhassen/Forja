use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    middleware::Next,
    response::Response,
};
use std::sync::Arc;

use crate::pairing::PairingState;

pub async fn require_bearer_token(
    pairing: Arc<PairingState>,
    mut req: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    let auth = req
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    let token = auth
        .strip_prefix("Bearer ")
        .unwrap_or("")
        .trim()
        .to_string();
    if token.is_empty() || !pairing.validate_token(&token) {
        return Err(StatusCode::UNAUTHORIZED);
    }
    pairing.touch_token(&token);
    req.extensions_mut().insert(token);
    Ok(next.run(req).await)
}

/// Media GETs use a short-lived `?st=` ticket (players often cannot send Bearer).
pub async fn require_stream_ticket(
    pairing: Arc<PairingState>,
    req: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    let ticket = req
        .headers()
        .get("x-forja-stream-ticket")
        .and_then(|v| v.to_str().ok())
        .map(str::to_string)
        .or_else(|| query_param(req.uri().query().unwrap_or(""), "st"))
        .unwrap_or_default();
    if ticket.is_empty() || !pairing.validate_stream_ticket(&ticket) {
        return Err(StatusCode::UNAUTHORIZED);
    }
    pairing.touch_stream_ticket(&ticket);
    Ok(next.run(req).await)
}

fn query_param(query: &str, key: &str) -> Option<String> {
    for pair in query.split('&') {
        let mut parts = pair.splitn(2, '=');
        let k = parts.next()?;
        let v = parts.next().unwrap_or("");
        if k == key && !v.is_empty() {
            return Some(urlencoding::decode(v).unwrap_or(v.into()).into_owned());
        }
    }
    None
}
