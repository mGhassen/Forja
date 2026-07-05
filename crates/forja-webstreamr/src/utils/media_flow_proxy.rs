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

#[derive(Debug, Clone, Deserialize)]
pub struct MfpStreamResponse {
    pub mediaflow_proxy_url: String,
    pub destination_url: String,
    #[serde(default)]
    pub query_params: Option<HashMap<String, serde_json::Value>>,
    #[serde(default)]
    pub request_headers: Option<HashMap<String, serde_json::Value>>,
}

pub fn build_extractor_api_url(config: &MfpConfig, host: &str, embed_url: &str) -> Option<String> {
    let trimmed = config.base_url.trim().trim_end_matches('/');
    let base = trimmed
        .trim_start_matches("https://")
        .trim_start_matches("http://");
    if base.is_empty() {
        return None;
    }
    let scheme = if trimmed.starts_with("http://") {
        "http"
    } else {
        "https"
    };
    let mut url = Url::parse(&format!("{scheme}://{base}/extractor/video")).ok()?;
    {
        let mut qp = url.query_pairs_mut();
        qp.append_pair("host", host);
        qp.append_pair("api_password", &config.password);
        qp.append_pair("d", embed_url);
        for (k, v) in &config.headers {
            qp.append_pair(&format!("h_{}", k.to_lowercase()), v);
        }
    }
    Some(url.to_string())
}

pub fn build_redirect_url(config: &MfpConfig, host: &str, embed_url: &str) -> Option<String> {
    let mut url = Url::parse(&build_extractor_api_url(config, host, embed_url)?).ok()?;
    url.query_pairs_mut().append_pair("redirect_stream", "true");
    Some(url.to_string())
}

fn json_value_to_string(v: &serde_json::Value) -> String {
    match v {
        serde_json::Value::String(s) => s.clone(),
        _ => v.to_string(),
    }
}

pub fn finalize_stream_url(result: &MfpStreamResponse) -> Option<String> {
    let mut url = Url::parse(&result.mediaflow_proxy_url).ok()?;
    {
        let mut qp = url.query_pairs_mut();
        if let Some(extra) = &result.query_params {
            for (k, v) in extra {
                qp.append_pair(k, &json_value_to_string(v));
            }
        }
        if let Some(headers) = &result.request_headers {
            for (k, v) in headers {
                qp.append_pair(&format!("h_{k}"), &json_value_to_string(v));
            }
        }
        qp.append_pair("d", &result.destination_url);
    }
    Some(url.to_string())
}

async fn fetch_stream_url(api_url: String) -> Option<String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(20))
        .build()
        .ok()?;
    let result: MfpStreamResponse = client.get(api_url).send().await.ok()?.json().await.ok()?;
    finalize_stream_url(&result)
}

pub fn build_stream_url(config: &MfpConfig, host: &str, embed_url: &str) -> Option<String> {
    let api_url = build_extractor_api_url(config, host, embed_url)?;
    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .ok()?;
    rt.block_on(fetch_stream_url(api_url))
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

    #[test]
    fn build_extractor_api_url_supports_http_base() {
        let config = MfpConfig {
            base_url: "http://127.0.0.1:8080".into(),
            password: "secret".into(),
            headers: HashMap::new(),
        };
        let url = build_extractor_api_url(&config, "LuluStream", "https://lulu.example/e/x").unwrap();
        assert!(url.starts_with("http://127.0.0.1:8080/extractor/video"));
        assert!(url.contains("host=LuluStream"));
    }

    #[test]
    fn finalizes_stream_url_from_response() {
        let response = MfpStreamResponse {
            mediaflow_proxy_url: "https://mfp.example/proxy/stream".into(),
            destination_url: "https://cdn.example/master.m3u8".into(),
            query_params: Some(HashMap::from([(
                "token".into(),
                serde_json::Value::String("abc".into()),
            )])),
            request_headers: Some(HashMap::from([(
                "Referer".into(),
                serde_json::Value::String("https://embed.example/".into()),
            )])),
        };
        let url = finalize_stream_url(&response).unwrap();
        assert!(url.contains("token=abc"));
        assert!(url.contains("h_Referer="));
        assert!(url.contains("d=https%3A%2F%2Fcdn.example%2Fmaster.m3u8"));
    }
}
