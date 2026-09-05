//! Forja Engine HTTP plugins — QuickJS on tokio (one runtime per extract).
//! Also owns provider reliability scoring (server/stream up/down store).

mod chrome_fetch;
mod crypto_host;
mod extract;
mod kisskh_kkey;
mod provider_health;
mod scrypt_pow;

pub use extract::{extract, ExtractRequest, ExtractResult, HopScript};
pub use provider_health::{handle_health_json, provider_from_memory_key, ProviderHealthStore};
