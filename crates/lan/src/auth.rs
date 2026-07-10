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
    req.extensions_mut().insert(token);
    Ok(next.run(req).await)
}
