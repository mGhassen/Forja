pub mod debrid;
pub mod iptv;
pub mod kisskh;
pub mod nuvio;
pub mod service111477;
pub mod stremio_addon;
pub mod torrentio;

use std::sync::Arc;

use crate::provider::Provider;

pub fn built_in() -> Vec<Arc<dyn Provider>> {
    vec![
        Arc::new(service111477::Service111477Provider),
        Arc::new(nuvio::NuvioProvider),
        Arc::new(kisskh::KisskhProvider),
        Arc::new(torrentio::TorrentioProvider),
        Arc::new(stremio_addon::StremioAddonProvider),
        Arc::new(debrid::DebridProvider),
        Arc::new(iptv::IptvProvider),
    ]
}
