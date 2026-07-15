//! Extract Xtream-Codes portal credentials from free-form text
//! (Reddit posts, paste dumps, XML2 lists).

use regex::Regex;
use serde::Serialize;
use std::collections::BTreeMap;
use std::sync::LazyLock;

static URL_PARAM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?i)(https?://[^?\s"'<]+)\?(?:[^\s"'<]*?&)?(?:username|user)=([^&\s"'<]+)\s*&(?:password|pass)=([^&\s"'<]+)"#,
    )
    .expect("url_param regex")
});

/// Label fallback for posts without a full get.php?username=…&password=… URL.
/// Matches English / Portuguese / Spanish labels and unicode smallcaps variants.
static LABEL: LazyLock<Regex> = LazyLock::new(|| {
    // Keep close to Dart IptvScraper._label — Host/User/Pass (+ i18n / smallcaps).
    // `(?s)` so `.` spans newlines. Use `\W+` (not `\W*?`) after labels so the
    // value capture cannot swallow the colon.
    Regex::new(
        r#"(?is)(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Real|URL|🔗|🌍|🌐)\W+(https?://[^<\s"']+).{1,500}?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|👤)\W+([^\s|<"'\n]+).{1,200}?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|🔑)\W+([^\s|<"'\n]+)"#,
    )
    .expect("label regex")
});

static BLOCK_TAGS: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)<(?:p|br|div|li|h\d)[^>]*>").expect("block tags"));
static ANY_TAG: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<[^>]+>").expect("any tag"));
static WHITESPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s+").expect("whitespace"));
static PATH_SUFFIX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)/(?:get|live|portal|c|index|playlist|player_api|xmltv|index\.php|portal\.php)\.php$",
    )
    .expect("path suffix")
});
static CRED_SPLIT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[ \n&?]").expect("cred split"));

const JUNK_TOKENS: &[&str] = &[
    "type=m3u",
    "output=ts",
    "password=",
    "username=",
    "password",
    "username",
];

const JUNK_CODE_MARKERS: &[&str] = &[
    "Array.isArray",
    "prototype.",
    "function(",
    "var ",
    "const ",
    "let ",
    "return!",
    "void ",
    ".message}",
    "window.",
    "document.",
];

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct Portal {
    pub url: String,
    pub username: String,
    pub password: String,
    pub source: String,
}

impl Portal {
    pub fn key(&self) -> String {
        format!("{}|{}|{}", self.url, self.username, self.password).to_lowercase()
    }
}

/// Extract unique portals from free-form text.
pub fn extract_portals(raw_text: &str, source: &str) -> Vec<Portal> {
    if raw_text.len() < 15 || is_junk_code(raw_text) {
        return Vec::new();
    }
    let cleaned = clean_htmlish(raw_text);
    let mut acc: BTreeMap<String, Portal> = BTreeMap::new();

    for caps in URL_PARAM.captures_iter(&cleaned) {
        finalize(
            &mut acc,
            caps.get(1).map(|m| m.as_str()).unwrap_or(""),
            caps.get(2).map(|m| m.as_str()).unwrap_or(""),
            caps.get(3).map(|m| m.as_str()).unwrap_or(""),
            source,
        );
    }
    for caps in LABEL.captures_iter(&cleaned) {
        finalize(
            &mut acc,
            caps.get(1).map(|m| m.as_str()).unwrap_or(""),
            caps.get(2).map(|m| m.as_str()).unwrap_or(""),
            caps.get(3).map(|m| m.as_str()).unwrap_or(""),
            source,
        );
    }
    acc.into_values().collect()
}

fn clean_htmlish(raw: &str) -> String {
    let s = raw.replace("&amp;", "&").replace("&quot;", "\"");
    let s = BLOCK_TAGS.replace_all(&s, "\n");
    ANY_TAG.replace_all(&s, "").into_owned()
}

fn is_junk_code(text: &str) -> bool {
    let mut hits = 0;
    for m in JUNK_CODE_MARKERS {
        if text.contains(m) {
            hits += 1;
            if hits >= 2 {
                return true;
            }
        }
    }
    false
}

fn finalize(acc: &mut BTreeMap<String, Portal>, raw_url: &str, raw_user: &str, raw_pass: &str, source: &str) {
    let url = clean_portal_url(raw_url);
    let user = clean_cred(raw_user);
    let pass = clean_cred(raw_pass);
    if url.is_empty() || user.len() < 3 || pass.len() < 3 {
        return;
    }
    if user.contains("http") || pass.contains("http") {
        return;
    }
    let lu = user.to_lowercase();
    let lp = pass.to_lowercase();
    for j in JUNK_TOKENS {
        if lu.contains(j) || lp.contains(j) {
            return;
        }
    }
    let p = Portal {
        url,
        username: user,
        password: pass,
        source: source.to_string(),
    };
    acc.entry(p.key()).or_insert(p);
}

fn clean_portal_url(raw: &str) -> String {
    let mut clean = WHITESPACE.replace_all(raw, "").into_owned();
    if let Some(q) = clean.find('?') {
        clean.truncate(q);
    }
    clean = clean.trim().to_string();
    if let Some(at) = clean.rfind('@') {
        clean = format!("http://{}", &clean[at + 1..]);
    }
    clean = PATH_SUFFIX.replace(&clean, "").into_owned();
    while clean.ends_with('/') {
        clean.pop();
    }
    if !clean.starts_with("http") {
        clean = format!("http://{clean}");
    }
    clean
}

fn clean_cred(raw: &str) -> String {
    let mut s = raw;
    while s.starts_with('=') {
        s = &s[1..];
    }
    CRED_SPLIT
        .split(s)
        .next()
        .unwrap_or("")
        .trim()
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_get_php_url_params() {
        let text = "try http://panel.example:8080/get.php?username=alice&password=secret99 here";
        let portals = extract_portals(text, "Catalog");
        assert_eq!(portals.len(), 1);
        assert_eq!(portals[0].url, "http://panel.example:8080");
        assert_eq!(portals[0].username, "alice");
        assert_eq!(portals[0].password, "secret99");
        assert_eq!(portals[0].source, "Catalog");
    }

    #[test]
    fn extracts_host_user_pass_labels() {
        let text = "Host: https://tv.example.com\nUsername: bobuser\nPassword: pass1234";
        let portals = extract_portals(text, "Catalog");
        assert_eq!(portals.len(), 1, "got: {portals:?}");
        assert_eq!(portals[0].url, "https://tv.example.com");
        assert_eq!(portals[0].username, "bobuser");
        assert_eq!(portals[0].password, "pass1234");
    }

    #[test]
    fn rejects_junk_js() {
        let text = "Array.isArray(x); function(y) { return!; window.foo }";
        assert!(extract_portals(text, "Catalog").is_empty());
    }

    #[test]
    fn dedupes_by_key() {
        let text = r#"
http://a.example/get.php?username=u123&password=p12345
http://a.example/get.php?username=u123&password=p12345
"#;
        assert_eq!(extract_portals(text, "Catalog").len(), 1);
    }
}
