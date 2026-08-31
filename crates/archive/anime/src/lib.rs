//! Archived anime stream extractors + resolve.
//!
//! Hub browse is `plugins/hubs/anime` (JS). Stream extract is
//! `plugins/providers/**`. This crate is not linked from `ffi`.

mod extractors;
mod http;
mod resolve;

pub use extractors::extractor_json as anime_extractor_json;
pub use resolve::resolve_json as anime_resolve_json;
