//! Forja Live catalog FFI stub.
//!
//! Schedule rows come from engine JS plugins only. Native fetch arms were removed;
//! this action stays so older hosts get an empty `items` list instead of unknown-action.

use serde_json::Value;

use crate::fetch::ok_items;

/// Fetch one Forja Live catalog plugin by engine id (`catalog-*`).
pub fn fetch_catalog(_catalog_id: &str, _config: &Value) -> String {
    ok_items(vec![])
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn unknown_catalog_returns_empty_items() {
        let raw = fetch_catalog("catalog-nope", &json!({}));
        let parsed: Value = serde_json::from_str(&raw).unwrap();
        assert!(parsed.get("items").unwrap().as_array().unwrap().is_empty());
    }
}
