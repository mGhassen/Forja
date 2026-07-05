mod bytes;
mod packed;
mod resolution;

pub use bytes::parse_bytes;
pub use packed::{extract_url_from_packed, extract_url_from_text};
pub use resolution::find_height;
