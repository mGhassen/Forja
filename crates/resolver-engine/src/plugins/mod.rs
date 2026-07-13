pub mod debrid;
pub mod iptv;
pub mod kisskh;
pub mod nuvio;
pub mod service111477;
pub mod stremio_addon;
pub mod template_embed;
pub mod torrentio;
pub mod vidsrc;
pub mod videasy;
pub mod webstreamr;

use std::sync::Arc;

use crate::provider::Provider;

pub fn built_in() -> Vec<Arc<dyn Provider>> {
    vec![
        Arc::new(webstreamr::WebstreamrProvider),
        Arc::new(vidsrc::VidsrcProvider),
        Arc::new(videasy::VideasyProvider),
        Arc::new(service111477::Service111477Provider),
        Arc::new(template_embed::VidlinkProvider),
        Arc::new(template_embed::VixsrcProvider),
        Arc::new(template_embed::VidnestProvider),
        Arc::new(template_embed::VidzeeProvider),
        Arc::new(template_embed::VidrockProvider),
        Arc::new(nuvio::NuvioProvider),
        Arc::new(kisskh::KisskhProvider),
        Arc::new(torrentio::TorrentioProvider),
        Arc::new(stremio_addon::StremioAddonProvider),
        Arc::new(debrid::DebridProvider),
        Arc::new(iptv::IptvProvider),
    ]
}
