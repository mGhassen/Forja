use proxy::mega::{self, MegaResolveResponse};
use tokio::runtime::Runtime;

pub fn mega_resolve_json(runtime: &Runtime, embed_url: String) -> String {
    runtime
        .block_on(async {
            let resp = mega::resolve(&embed_url).await;
            serde_json::to_string(&resp).unwrap_or_else(|_| {
                serde_json::to_string(&MegaResolveResponse {
                    url: None,
                    size: None,
                    error: Some("serialize failed".into()),
                })
                .unwrap_or_else(|_| "{}".into())
            })
        })
}
