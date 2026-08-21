//! Forja Engine HTTP plugins — QuickJS on tokio (one runtime per extract).

mod extract;
mod stream_crypto;

pub use extract::{extract, ExtractRequest, ExtractResult};
pub use stream_crypto::{decrypt as stream_decrypt, StreamCryptoError};
