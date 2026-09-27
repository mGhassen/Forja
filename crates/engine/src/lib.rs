//! Forja Engine HTTP plugins — QuickJS on tokio (one runtime per extract).
//! Also owns provider reliability scoring (server/stream up/down store).

mod chrome_fetch;
mod crypto_host;
mod extract;
mod extract_events;
mod provider_health;
mod scrypt_kdf;

pub use extract::{extract, extract_in_job, ExtractRequest, ExtractResult, HopScript};
pub use extract_events::{clear as clear_extract_events, take as take_extract_events};
pub use provider_health::{handle_health_json, provider_from_memory_key, ProviderHealthStore};
