use std::collections::HashMap;

pub type Config = HashMap<String, String>;

pub const APP_NAME: &str = "WebStreamr";

/// Default when no plugin config is supplied.
///
/// Matches Dart [WebStreamrSettings.defaultCountryCodes]: enable every
/// supported country code so regional sources (KinoGer/DE, MegaKino, …)
/// participate out of the box. Callers that need a narrow set must pass an
/// explicit config map.
pub fn default_config() -> Config {
    const COUNTRY_CODES: &[&str] = &[
        "multi", "al", "ar", "bg", "bl", "cs", "de", "el", "en", "es", "et", "fa", "fr",
        "gu", "he", "hi", "hr", "hu", "id", "it", "ja", "kn", "ko", "lt", "lv", "ml", "mr",
        "mx", "nl", "no", "pa", "pl", "pt", "ro", "ru", "sk", "sl", "sr", "ta", "te", "th",
        "tr", "uk", "vi", "zh",
    ];
    COUNTRY_CODES
        .iter()
        .map(|cc| ((*cc).into(), "on".into()))
        .collect()
}

pub fn show_errors(config: &Config) -> bool {
    config.contains_key("showErrors")
}

pub fn show_external_urls(config: &Config) -> bool {
    config.contains_key("includeExternalUrls")
}

pub fn is_extractor_disabled(config: &Config, extractor_id: &str) -> bool {
    config.contains_key(&format!("disableExtractor_{extractor_id}"))
}

pub fn is_resolution_excluded(config: &Config, resolution: &str) -> bool {
    config.contains_key(&format!("excludeResolution_{resolution}"))
}

pub fn supports_media_flow_proxy(config: &Config) -> bool {
    config
        .get("mediaFlowProxyUrl")
        .is_some_and(|v| !v.trim().is_empty())
}

pub fn mfp_config_json(config: &Config, headers: HashMap<String, String>) -> Option<String> {
    let base = config.get("mediaFlowProxyUrl")?.trim();
    if base.is_empty() {
        return None;
    }
    Some(
        serde_json::json!({
            "base_url": base,
            "password": config.get("mediaFlowProxyPassword").cloned().unwrap_or_default(),
            "headers": headers,
        })
        .to_string(),
    )
}

pub fn country_enabled(config: &Config, country_code: &str) -> bool {
    config.contains_key(country_code)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_mfp_and_disabled_extractor() {
        let mut c = default_config();
        c.insert("mediaFlowProxyUrl".into(), "https://mfp.example".into());
        c.insert("disableExtractor_mixdrop".into(), "on".into());
        assert!(supports_media_flow_proxy(&c));
        assert!(is_extractor_disabled(&c, "mixdrop"));
        assert!(!is_extractor_disabled(&c, "voe"));
    }

    #[test]
    fn default_config_enables_regional_countries() {
        let c = default_config();
        assert!(country_enabled(&c, "multi"));
        assert!(country_enabled(&c, "en"));
        assert!(country_enabled(&c, "de"));
        assert!(country_enabled(&c, "hi"));
        assert!(country_enabled(&c, "fr"));
    }
}
