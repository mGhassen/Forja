use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::context::ResolverContext;
use crate::request::StreamRequest;
use crate::result::{HostResolveRequest, StreamResult};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProviderKind {
    RustNative,
    HostRequired,
}

#[derive(Debug, Error)]
pub enum ProviderError {
    #[error("cancelled")]
    Cancelled,
    #[error("no streams")]
    NoStreams,
    #[error("host resolve required")]
    HostRequired(HostResolveRequest),
    #[error("{0}")]
    Message(String),
}

pub trait Provider: Send + Sync {
    fn id(&self) -> &str;
    fn kind(&self) -> ProviderKind;
    fn resolve(
        &self,
        request: &StreamRequest,
        ctx: &ResolverContext,
    ) -> Result<StreamResult, ProviderError>;
}
