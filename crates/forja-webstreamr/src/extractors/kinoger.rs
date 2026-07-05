use crate::types::{ExtractResult, StreamFormat};
use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, KeyIvInit};
use serde::Deserialize;
use std::collections::HashMap;

type Aes128CbcDec = cbc::Decryptor<aes::Aes128>;

const KEY_HEX: &str = "6b69656d7469656e6d75613931316361";
const IV_HEX: &str = "313233343536373839306f6975797472";

#[derive(Debug, Deserialize)]
struct KinoGerPayload {
    source: String,
    title: Option<String>,
}

pub fn supports_host(host: &str) -> bool {
    matches!(
        host,
        "asianembed.cam"
            | "disneycdn.net"
            | "dzo.vidplayer.live"
            | "filedecrypt.link"
            | "filma365.strp2p.site"
            | "flimmer.rpmvip.com"
            | "flixfilmesonline.strp2p.site"
            | "kinoger.p2pplay.pro"
            | "kinoger.re"
            | "moflix.rpmplay.xyz"
            | "moflix.upns.xyz"
            | "player.upn.one"
            | "securecdn.shop"
            | "shiid4u.upn.one"
            | "srbe84.vidplayer.live"
            | "strp2p.site"
            | "t1.p2pplay.pro"
            | "tuktuk.rpmvid.com"
            | "ultrastream.online"
            | "videoland.cfd"
            | "videoshar.uns.bio"
            | "w1tv.xyz"
            | "wasuytm.store"
    ) || host.contains("kinoger")
}

pub fn extract_from_html(hex_body: &str, page_url: &str) -> Option<ExtractResult> {
    let page = url::Url::parse(page_url).ok()?;
    let host = page.host_str()?;
    if !supports_host(host) {
        return None;
    }
    let origin = format!("{}://{}", page.scheme(), host);

    let trimmed = hex_body.trim();
    let hex_str = if trimmed.len() > 1 {
        &trimmed[..trimmed.len() - 1]
    } else {
        trimmed
    };
    let encrypted = hex::decode(hex_str).ok()?;
    let key = hex::decode(KEY_HEX).ok()?;
    let iv = hex::decode(IV_HEX).ok()?;
    let key: [u8; 16] = key.try_into().ok()?;
    let iv: [u8; 16] = iv.try_into().ok()?;

    let mut buf = encrypted;
    let plain = Aes128CbcDec::new(&key.into(), &iv.into())
        .decrypt_padded_mut::<Pkcs7>(&mut buf)
        .ok()?;
    let payload: KinoGerPayload = serde_json::from_slice(plain).ok()?;

    let mut request_headers = HashMap::new();
    request_headers.insert("Origin".into(), origin.clone());
    request_headers.insert("Referer".into(), format!("{origin}/"));

    Some(ExtractResult {
        url: payload.source,
        format: StreamFormat::Hls,
        title: payload.title,
        height: None,
        yt_id: None,
        request_headers: Some(request_headers),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use aes::cipher::{block_padding::Pkcs7, BlockEncryptMut, KeyIvInit};

    type Aes128CbcEnc = cbc::Encryptor<aes::Aes128>;

    #[test]
    fn decrypts_kinoger_hex_body() {
        let plain =
            br#"{"source":"https://cdn.kinoger.example/stream.m3u8","title":"KinoGer Title"}"#;
        let key: [u8; 16] = hex::decode(KEY_HEX).unwrap().try_into().unwrap();
        let iv: [u8; 16] = hex::decode(IV_HEX).unwrap().try_into().unwrap();
        let mut buf = vec![0u8; plain.len() + 16];
        buf[..plain.len()].copy_from_slice(plain);
        let enc = Aes128CbcEnc::new(&key.into(), &iv.into())
            .encrypt_padded_mut::<Pkcs7>(&mut buf, plain.len())
            .unwrap();
        let body = format!("{};", hex::encode(enc));
        let r = extract_from_html(&body, "https://kinoger.re/api/v1/video?id=x").unwrap();
        assert_eq!(r.url, "https://cdn.kinoger.example/stream.m3u8");
        assert_eq!(r.title.as_deref(), Some("KinoGer Title"));
    }
}
