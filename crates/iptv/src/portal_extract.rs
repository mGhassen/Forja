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

/// Host/Server → User → Pass (classic Reddit cards).
/// Emoji may prefix a word label; bare emoji alone is not a label (avoids
/// capturing `ꜱᴇʀᴠᴇʀ` as the URL when the line is `🌐 ꜱᴇʀᴠᴇʀ : http://…`).
static LABEL_HOST_FIRST: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?is)(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?://[^<\s"']+).{1,500}?(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,200}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+)"#,
    )
    .expect("label_host_first regex")
});

/// User → Pass → Server (Hit Hunter–style cards).
static LABEL_USER_FIRST: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?is)(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?://[^<\s"']+)"#,
    )
    .expect("label_user_first regex")
});

/// Tabular dumps: `host:port   user:pass   0/1 …`
static TABLE_LINE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?im)^[^\S\n]*((?:(?:\d{1,3}\.){3}\d{1,3}|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,})):([1-9]\d{1,4})[^\S\n]+([A-Za-z0-9._@+-]{3,64}):(\S{3,64})"#,
    )
    .expect("table_line regex")
});

/// IPTV_ZONENEW cards: `🔗 http://…` then `👤 USERNAME :` / `🔑 PASSWORD :`.
static EMOJI_LINK: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?:🔗|🌍|🌐)\s*(https?://[^\s<"']+)"#).expect("emoji_link regex")
});

/// Emoji-required so we never match `username=` inside get.php query strings.
static EMOJI_CREDS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?is)(?:👤|👑)\s*(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\s*[:=]\s*([^\s|<"'\n]+)[\s\S]{0,240}?(?:🔑|🔐)\s*(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\s*[:=]\s*([^\s|<"'\n]+)"#,
    )
    .expect("emoji_creds regex")
});

static BLOCK_TAGS: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)<(?:p|br|div|li|h\d)[^>]*>").expect("block tags"));
static ANY_TAG: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<[^>]+>").expect("any tag"));
static MARKDOWN_LINK: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\[([^\]]*)]\((https?://[^)\s]+)\)").expect("markdown_link regex")
});
static ANGLE_URL: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"<(https?://[^>\s]+)>").expect("angle_url regex"));
static WHITESPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s+").expect("whitespace"));
static PATH_SUFFIX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)/(?:get|live|portal|c|index|playlist|player_api|xmltv|index\.php|portal\.php)\.php$",
    )
    .expect("path suffix")
});
static CRED_SPLIT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[ \n&?]").expect("cred split"));
static TRAILING_JUNK: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"[\]>"')]+$"#).expect("trailing_junk"));

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
    for caps in LABEL_HOST_FIRST.captures_iter(&cleaned) {
        finalize(
            &mut acc,
            caps.get(1).map(|m| m.as_str()).unwrap_or(""),
            caps.get(2).map(|m| m.as_str()).unwrap_or(""),
            caps.get(3).map(|m| m.as_str()).unwrap_or(""),
            source,
        );
    }
    for caps in LABEL_USER_FIRST.captures_iter(&cleaned) {
        // groups: user, pass, url
        finalize(
            &mut acc,
            caps.get(3).map(|m| m.as_str()).unwrap_or(""),
            caps.get(1).map(|m| m.as_str()).unwrap_or(""),
            caps.get(2).map(|m| m.as_str()).unwrap_or(""),
            source,
        );
    }
    for caps in TABLE_LINE.captures_iter(&cleaned) {
        let host = caps.get(1).map(|m| m.as_str()).unwrap_or("");
        let port = caps.get(2).map(|m| m.as_str()).unwrap_or("");
        let user = caps.get(3).map(|m| m.as_str()).unwrap_or("");
        let pass = caps.get(4).map(|m| m.as_str()).unwrap_or("");
        if host.is_empty() || port.is_empty() {
            continue;
        }
        finalize(
            &mut acc,
            &format!("{host}:{port}"),
            user,
            pass,
            source,
        );
    }
    extract_emoji_link_cards(&cleaned, &mut acc, source);
    acc.into_values().collect()
}

enum EmojiMark<'a> {
    Url { index: usize, url: &'a str },
    Cred { index: usize, user: &'a str, pass: &'a str },
}

fn extract_emoji_link_cards(cleaned: &str, acc: &mut BTreeMap<String, Portal>, source: &str) {
    let mut marks: Vec<EmojiMark<'_>> = Vec::new();
    for caps in EMOJI_LINK.captures_iter(cleaned) {
        let full = caps.get(0).expect("full");
        let url = caps.get(1).map(|m| m.as_str()).unwrap_or("");
        if url.is_empty() {
            continue;
        }
        marks.push(EmojiMark::Url {
            index: full.start(),
            url,
        });
    }
    for caps in EMOJI_CREDS.captures_iter(cleaned) {
        let full = caps.get(0).expect("full");
        let user = caps.get(1).map(|m| m.as_str()).unwrap_or("");
        let pass = caps.get(2).map(|m| m.as_str()).unwrap_or("");
        if user.is_empty() || pass.is_empty() {
            continue;
        }
        marks.push(EmojiMark::Cred {
            index: full.start(),
            user,
            pass,
        });
    }
    marks.sort_by_key(|m| match m {
        EmojiMark::Url { index, .. } | EmojiMark::Cred { index, .. } => *index,
    });

    let mut last_url: Option<&str> = None;
    for mark in marks {
        match mark {
            EmojiMark::Url { url, .. } => last_url = Some(url),
            EmojiMark::Cred { user, pass, .. } => {
                if let Some(url) = last_url {
                    finalize(acc, url, user, pass, source);
                }
            }
        }
    }
}

fn clean_htmlish(raw: &str) -> String {
    let s = raw.replace("&amp;", "&").replace("&quot;", "\"");
    let s = MARKDOWN_LINK.replace_all(&s, "$2");
    let s = ANGLE_URL.replace_all(&s, "$1");
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
    // Keep stalker / MAC-bridge portals — do not drop them.
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
    clean = TRAILING_JUNK.replace(&clean, "").into_owned();
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
    let decoded = percent_decode(s);
    let trimmed = TRAILING_JUNK.replace(decoded.trim(), "");
    CRED_SPLIT
        .split(trimmed.as_ref())
        .next()
        .unwrap_or("")
        .trim()
        .to_string()
}

fn percent_decode(raw: &str) -> String {
    let bytes = raw.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let h1 = from_hex(bytes[i + 1]);
            let h2 = from_hex(bytes[i + 2]);
            if let (Some(a), Some(b)) = (h1, h2) {
                out.push((a << 4) | b);
                i += 3;
                continue;
            }
        }
        if bytes[i] == b'+' {
            out.push(b' ');
        } else {
            out.push(bytes[i]);
        }
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn from_hex(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
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
    fn extracts_unicode_user_first_card() {
        let text = "\
╭───✦
├● 👑 ᴜꜱᴇʀ : cotty.812@gmail.com
├● 🔐 ᴩᴀꜱꜱ : cotty.812@87
├● ✅ ꜱᴛᴀᴛᴜꜱ : Active
├● 🌐 ꜱᴇʀᴠᴇʀ : http://tvmate.icu:8080
╰───✦
";
        let portals = extract_portals(text, "Catalog");
        assert_eq!(portals.len(), 1, "got: {portals:?}");
        assert_eq!(portals[0].url, "http://tvmate.icu:8080");
        assert_eq!(portals[0].username, "cotty.812@gmail.com");
        assert_eq!(portals[0].password, "cotty.812@87");
    }

    #[test]
    fn extracts_table_host_user_pass() {
        let text = "\
009900.live:8080                      iFnzn9zOnd:P4gsG7edtl                                  0/500      no_expiry  Active
0g7hljf4wx.sasa24.xyz:80              LUCIO-ACE:Afy6QeKUMY                                   1/1        Sep23      2026
103.240.150.220:80                    4:987654321                                            1/1        Jul24      2026
1.fu4-pro.cfd:80                      ogwv5yz53q2:sojjnxkwxr                                 1/1        May15      2027
";
        let portals = extract_portals(text, "Catalog");
        assert_eq!(portals.len(), 3, "got: {portals:?}");
        assert!(portals.iter().any(|p| {
            p.url == "http://009900.live:8080"
                && p.username == "iFnzn9zOnd"
                && p.password == "P4gsG7edtl"
        }));
        assert!(portals.iter().any(|p| p.username == "LUCIO-ACE"));
        assert!(portals.iter().any(|p| p.username == "ogwv5yz53q2"));
        // user len < 3 rejected
        assert!(!portals.iter().any(|p| p.username == "4"));
    }

    #[test]
    fn keeps_stalker_mac_bridge() {
        let text = "\
Real: http://dinofox.sbs:80/c/
Mac: 00:1A:79:9C:3D:9D
m3uLink:http://dinofox.sbs:80/get.php?username=play&password=live.php?mac=00:1A:79:9C:3D:9D&stream=1&type=m3u_plus
";
        let portals = extract_portals(text, "Catalog");
        assert!(
            !portals.is_empty(),
            "stalker / MAC-bridge must be kept, not rejected"
        );
        assert!(portals.iter().any(|p| p.username == "play"));
    }

    #[test]
    fn rejects_junk_js() {
        let text = "Array.isArray(x); function(y) { return!; window.foo }";
        assert!(extract_portals(text, "Catalog").is_empty());
    }

    #[test]
    fn extracts_zonenew_emoji_link_cards() {
        let text = r#"📡 M3U/XTREAM
🔗 http://mediaiptv.tv/get.php?username=d0:d0:03:55:8e:67&password=APaY:6:7xMAGc5&type=m3u
🚦 STATUS : Active
👤 USERNAME : d0:d0:03:55:8e:67
🔑 PASSWORD : APaY:6:7xMAGc5

🚦 STATUS : Active
👤 USERNAME : gxdcxnbf
🔑 PASSWORD : 1eZr21rf1D

🔗 http://fortv.cc:8080/get.php?username=Y3DvY8&password=934867&type=m3u_plus&output=m3u8
👤 USERNAME : Y3DvY8
🔑 PASSWORD : 934867
"#;
        let portals = extract_portals(text, "Catalog");
        assert!(
            portals.iter().any(|p| {
                p.url == "http://mediaiptv.tv"
                    && p.username == "d0:d0:03:55:8e:67"
                    && p.password == "APaY:6:7xMAGc5"
            }),
            "got: {portals:?}"
        );
        assert!(
            portals.iter().any(|p| p.username == "gxdcxnbf" && p.password == "1eZr21rf1D"),
            "orphan after 🔗 must inherit prior host; got: {portals:?}"
        );
        assert!(portals.iter().any(|p| p.username == "Y3DvY8"), "got: {portals:?}");
    }

    #[test]
    fn extracts_emoji_link_without_get_php_query() {
        let text = "🔗 http://mediaiptv.tv:8080\n👤 USERNAME : aliceuser\n🔑 PASSWORD : secretpass99";
        let portals = extract_portals(text, "Catalog");
        assert_eq!(portals.len(), 1, "got: {portals:?}");
        assert_eq!(portals[0].url, "http://mediaiptv.tv:8080");
        assert_eq!(portals[0].username, "aliceuser");
        assert_eq!(portals[0].password, "secretpass99");
    }

    #[test]
    fn extracts_markdown_get_php_link() {
        let text = "[http://x.tv/get.php?username=bobuser&password=bobpass99&type=m3u](http://x.tv/get.php?username=bobuser&password=bobpass99&type=m3u)";
        let portals = extract_portals(text, "Catalog");
        assert_eq!(portals.len(), 1, "got: {portals:?}");
        assert_eq!(portals[0].username, "bobuser");
        assert_eq!(portals[0].password, "bobpass99");
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
