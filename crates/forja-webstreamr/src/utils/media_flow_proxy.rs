use serde::Deserialize;
use std::collections::HashMap;
use url::Url;

#[derive(Debug, Clone, Deserialize)]
pub struct MfpConfig {
    pub base_url: String,
    #[serde(default)]
    pub password: String,
    #[serde(default)]
    pub headers: HashMap<String, String>,
}

pub fn build_redirect_url(config: &MfpConfig, host: &str, embed_url: &str) -> Option<String> {
    let base = config
        .base_url
        .trim()
        .trim_start_matches("https://")
        .trim_start_matches("http://");
    if base.is_empty() {
        return None;
    }
    let mut url = Url::parse(&format!("https://{base}/extractor/video")).ok()?;
    {
        let mut qp = url.query_pairs_mut();
        qp.append_pair("host", host);
        qp.append_pair("api_password", &config.password);
        qp.append_pair("d", embed_url);
        qp.append_pair("redirect_stream", "true");
        for (k, v) in &config.headers {
            qp.append_pair(&format!("h_{}", k.to_lowercase()), v);
        }
    }
    Some(url.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_redirect_url_with_headers() {
        let config = MfpConfig {
            base_url: "https://mfp.example".into(),
            password: "secret".into(),
            headers: HashMap::from([("Referer".into(), "https://embed.example/".into())]),
        };
        let url = build_redirect_url(&config, "Mixdrop", "https://mixdrop.example/e/abc").unwrap();
        assert!(url.contains("host=Mixdrop"));
        assert!(url.contains("redirect_stream=true"));
        assert!(url.contains("h_referer="));
    }
}
