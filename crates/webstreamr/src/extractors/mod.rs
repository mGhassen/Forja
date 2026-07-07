mod dropload;
mod doodstream;
mod external;
mod fastream;
mod filelions;
mod filemoon;
mod fsst;
mod hubcloud;
mod hubdrive;
mod kinoger;
mod lulustream;
mod mixdrop;
mod rgshows;
mod savefiles;
mod streamembed;
mod streamtape;
mod supervideo;
mod uqload;
mod vidsrc;
mod vidora;
mod vixsrc;
mod voe;
mod youtube;

mod registry;

use crate::types::ExtractResult;
use crate::utils::MfpConfig;

pub use dropload::{extract_from_html as extract_dropload, supports_host as dropload_supports};
pub use external::{extract_from_html as extract_external, supports_host as external_supports};
pub use filemoon::{extract_from_html as extract_filemoon, supports_host as filemoon_supports};
pub use fsst::{extract_from_html as extract_fsst, supports_host as fsst_supports};
pub use hubcloud::{
    extract_from_html as extract_hubcloud, extract_links_from_html as extract_hubcloud_links,
    supports_host as hubcloud_supports,
};
pub use hubdrive::{extract_from_html as extract_hubdrive, supports_host as hubdrive_supports};
pub use kinoger::{extract_from_html as extract_kinoger, supports_host as kinoger_supports};
pub use rgshows::{extract_from_html as extract_rgshows, supports_host as rgshows_supports};
pub use savefiles::{extract_from_html as extract_savefiles, supports_host as savefiles_supports};
pub use streamembed::{extract_from_html as extract_streamembed, supports_host as streamembed_supports};
pub use supervideo::{extract_from_html as extract_supervideo, supports_host as supervideo_supports};
pub use vidsrc::{
    build_embed_url, extract_from_html_chain, extract_vidsrc_chain_json,
    resolve_vidsrc_embed_json,
};
pub use vidora::{extract_from_html as extract_vidora, supports_host as vidora_supports};
pub use vixsrc::{extract_from_html as extract_vixsrc, supports_host as vixsrc_supports};
pub use youtube::{extract_from_html as extract_youtube, supports_host as youtube_supports};

pub fn extract_embed_html(extractor_id: &str, html: &str, page_url: &str) -> Option<ExtractResult> {
    match extractor_id {
        "streamembed" => streamembed::extract_from_html(html, page_url),
        "savefiles" => savefiles::extract_from_html(html, page_url),
        "dropload" => dropload::extract_from_html(html, page_url),
        "supervideo" => supervideo::extract_from_html(html, page_url),
        "vidora" => vidora::extract_from_html(html, page_url),
        "fsst" => fsst::extract_from_html(html, page_url),
        "vixsrc" => vixsrc::extract_from_html(html, page_url),
        "kinoger" => kinoger::extract_from_html(html, page_url),
        "youtube" => youtube::extract_from_html(html, page_url),
        "filemoon" => filemoon::extract_from_html(html, page_url),
        "hubdrive" => hubdrive::extract_from_html(html, page_url),
        "hubcloud" => hubcloud::extract_from_html(html, page_url),
        "rgshows" => rgshows::extract_from_html(html, page_url),
        "external" => external::extract_from_html(html, page_url),
        "filelions" => filelions::extract_redirect_from_html(html, page_url),
        "voe" => voe::extract_redirect_from_html(html, page_url),
        _ => None,
    }
}

pub fn extract_mfp_embed_html(
    extractor_id: &str,
    html: &str,
    page_url: &str,
    mfp_config_json: &str,
    extra_html: &str,
) -> Option<ExtractResult> {
    let mfp: MfpConfig = serde_json::from_str(mfp_config_json).ok()?;
    match extractor_id {
        "mixdrop" => mixdrop::extract_from_html(html, page_url, &mfp),
        "streamtape" => streamtape::extract_from_html(html, page_url, &mfp),
        "uqload" => uqload::extract_from_html(html, page_url, &mfp),
        "doodstream" => doodstream::extract_from_html(html, page_url, &mfp, extra_html),
        "filelions" => filelions::extract_from_html(html, page_url, &mfp),
        "lulustream" => lulustream::extract_from_html(html, page_url, &mfp, extra_html),
        "fastream" => fastream::extract_from_html(html, page_url, &mfp, extra_html),
        "voe" => voe::extract_from_html(html, page_url, &mfp),
        _ => None,
    }
}

pub fn list_mfp_extractors() -> &'static [&'static str] {
    &[
        "mixdrop",
        "streamtape",
        "uqload",
        "doodstream",
        "filelions",
        "lulustream",
        "fastream",
        "voe",
    ]
}

pub use registry::{find_extractor_for_url, run_extractor, EmbedMeta, UrlResult};

pub fn list_html_extractors() -> &'static [&'static str] {
    &[
        "streamembed",
        "savefiles",
        "dropload",
        "supervideo",
        "vidora",
        "fsst",
        "vixsrc",
        "kinoger",
        "youtube",
        "filemoon",
        "hubdrive",
        "hubcloud",
        "rgshows",
        "external",
        "vidsrc",
    ]
}
