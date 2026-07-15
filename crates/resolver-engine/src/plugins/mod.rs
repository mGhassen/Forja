pub mod autoembed;
pub mod debrid;
pub mod iptv;
pub mod kisskh;
pub mod movies111;
pub mod moviesapi;
pub mod nuvio;
pub mod service111477;
pub mod stremio_addon;
pub mod torrentio;
pub mod two_embed;
pub mod videasy;
pub mod vidfast;
pub mod vidlink;
pub mod vidlove;
pub mod vidnest;
pub mod vidrock;
pub mod vidsrc;
pub mod vidsrcsbs;
pub mod vidsrcwin;
pub mod vidzee;
pub mod vixsrc;
pub mod webstreamr;

use std::sync::Arc;

use crate::provider::Provider;

pub fn built_in() -> Vec<Arc<dyn Provider>> {
    vec![
        Arc::new(webstreamr::WebstreamrProvider),
        Arc::new(vidsrc::VidsrcProvider),
        Arc::new(videasy::VideasyProvider),
        Arc::new(service111477::Service111477Provider),
        Arc::new(vidlink::VidlinkProvider),
        Arc::new(vixsrc::VixsrcProvider),
        Arc::new(vidnest::VidnestProvider),
        Arc::new(vidzee::VidzeeProvider),
        Arc::new(vidrock::VidrockProvider),
        Arc::new(vidfast::VidfastProvider),
        Arc::new(two_embed::TwoEmbedProvider),
        Arc::new(autoembed::AutoembedProvider),
        Arc::new(vidlove::VidloveProvider),
        Arc::new(vidsrcsbs::VidsrcsbsProvider),
        Arc::new(vidsrcwin::VidsrcwinProvider),
        Arc::new(movies111::Movies111Provider),
        Arc::new(moviesapi::MoviesapiProvider),
        Arc::new(nuvio::NuvioProvider),
        Arc::new(kisskh::KisskhProvider),
        Arc::new(torrentio::TorrentioProvider),
        Arc::new(stremio_addon::StremioAddonProvider),
        Arc::new(debrid::DebridProvider),
        Arc::new(iptv::IptvProvider),
    ]
}
