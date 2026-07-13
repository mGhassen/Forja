mod cache;
mod context;
mod cookies;
mod headers;
mod health;
mod health_store;
mod http;
mod orchestrator;
mod plugins;
mod provider;
mod registry;
mod request;
mod result;
mod scoring;

pub use cache::ResolveCache;
pub use context::ResolverContext;
pub use cookies::CookieJar;
pub use headers::HeaderManager;
pub use health::{provider_health_json, HealthChecker};
pub use health_store::ProviderHealthStore;
pub use http::{HttpClient, HttpResponse};
pub use orchestrator::{continue_with_host, resolve};
pub use provider::{Provider, ProviderError, ProviderKind};
pub use registry::ProviderRegistry;
pub use request::{ContinueRequest, HostResolveResult, ResolveSettings, StreamRequest};
pub use result::{
    HostResolveRequest, ResolvePhase, ResolveProgressEvent, ResolveResponse, StreamResult,
};
pub use scoring::{domain_label, rank_playable_sources, MAX_DISPLACEMENT};
