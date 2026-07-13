use std::collections::HashMap;
use std::time::Duration;

use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};

#[derive(Clone)]
pub struct HttpClient {
    client: Client,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HttpResponse {
    pub status: u16,
    pub body: String,
    #[serde(default)]
    pub headers: HashMap<String, String>,
}

impl HttpClient {
    pub fn new() -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .cookie_store(true)
            .build()
            .unwrap_or_else(|_| Client::new());
        Self { client }
    }

    pub fn get(
        &self,
        url: &str,
        headers: &HashMap<String, String>,
        timeout_secs: u64,
    ) -> Result<HttpResponse, String> {
        let mut req = self.client.get(url);
        for (k, v) in headers {
            req = req.header(k, v);
        }
        let resp = req
            .timeout(Duration::from_secs(timeout_secs.max(1)))
            .send()
            .map_err(|e| e.to_string())?;
        let status = resp.status().as_u16();
        let mut out_headers = HashMap::new();
        for (k, v) in resp.headers() {
            if let Ok(s) = v.to_str() {
                out_headers.insert(k.to_string(), s.to_string());
            }
        }
        let body = resp.text().map_err(|e| e.to_string())?;
        Ok(HttpResponse {
            status,
            body,
            headers: out_headers,
        })
    }
}

impl Default for HttpClient {
    fn default() -> Self {
        Self::new()
    }
}
