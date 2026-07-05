mod dropload;
mod savefiles;
mod streamembed;
mod supervideo;
mod vidsrc;
mod vidora;

use crate::types::ExtractResult;

pub use dropload::{extract_from_html as extract_dropload, supports_host as dropload_supports};
pub use savefiles::{extract_from_html as extract_savefiles, supports_host as savefiles_supports};
pub use streamembed::{extract_from_html as extract_streamembed, supports_host as streamembed_supports};
pub use supervideo::{extract_from_html as extract_supervideo, supports_host as supervideo_supports};
pub use vidsrc::{build_embed_url, extract_from_html_chain};
pub use vidora::{extract_from_html as extract_vidora, supports_host as vidora_supports};

pub fn extract_embed_html(extractor_id: &str, html: &str, page_url: &str) -> Option<ExtractResult> {
    match extractor_id {
        "streamembed" => streamembed::extract_from_html(html, page_url),
        "savefiles" => savefiles::extract_from_html(html, page_url),
        "dropload" => dropload::extract_from_html(html, page_url),
        "supervideo" => supervideo::extract_from_html(html, page_url),
        "vidora" => vidora::extract_from_html(html, page_url),
        _ => None,
    }
}

pub fn list_html_extractors() -> &'static [&'static str] {
    &[
        "streamembed",
        "savefiles",
        "dropload",
        "supervideo",
        "vidora",
        "vidsrc",
    ]
}
