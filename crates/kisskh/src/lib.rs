//! KissKH crypto helpers for engine-js provider plugins.
//!
//! Browse/play logic lives in `plugins/providers/kisskh.js` and
//! `plugins/hubs/asian_drama/kisskh.js`. Rust only supplies `kkey` for the
//! Episode/Sub `.png` API auth that JS calls via `ctx.crypto.kisskhKkey`.

mod kkey;

pub use kkey::{generate_kkey, KkeyKind};
