use stream_core::{
    rank_sources, PlayableSource, RankSourcesRequest, SourceDomain, MAX_PROVIDER_DISPLACEMENT,
};

pub fn rank_playable_sources(
    sources: Vec<PlayableSource>,
    device: stream_core::DevicePlaybackCapabilities,
    blocklist: Vec<String>,
) -> Vec<PlayableSource> {
    rank_sources(RankSourcesRequest {
        sources,
        device,
        blocklist,
    })
    .sources
}

pub fn domain_label(domain: SourceDomain) -> &'static str {
    match domain {
        SourceDomain::Movies => "movies",
        SourceDomain::Series => "series",
        SourceDomain::Anime => "anime",
        SourceDomain::AsianDrama => "asian_drama",
        SourceDomain::Iptv => "iptv",
        SourceDomain::Torrent => "torrent",
    }
}

pub const MAX_DISPLACEMENT: i32 = MAX_PROVIDER_DISPLACEMENT;
