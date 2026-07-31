//! KissKH `kkey` for `/api/DramaList/Episode/{id}.png` and `/api/Sub/{id}`.
//!
//! Port of consumet `extractors/kisskh/kkey.js` (AES-like block cipher over a
//! fixed site key schedule). Verified against live `kisskh.nl` Episode API.

#[path = "kkey_tables.rs"]
mod kkey_tables;

use kkey_tables::{RK, SBOX, T0, T1, T2, T3};

const HASH: &str = "mg3c3b04ba";
const VERSION: &str = "2.8.10";
const VI_GUID: &str = "62f176f3bb1b5b8e70e39932ad34a0c7";
const SUB_GUID: &str = "VgV52sWhwvBSf8BsM3BRY9weWiiCbtGp";
const PLATFORM_VER: &str = "4830201";
const IV: [i32; 4] = [22039283, 1457920463, 776125350, -1941999367];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum KkeyKind {
    Video,
    Subtitle,
}

fn calculate_hash(input: &str) -> i64 {
    // Match JS: `(hash << 5) - hash + charCode` where `<<` is ToInt32 but the
    // subtract/add stay as IEEE Number (can exceed i32 — e.g. ep 171699).
    let mut hash: i64 = 0;
    for ch in input.chars() {
        let c = ch as i64;
        let shifted = ((hash as i32).wrapping_shl(5)) as i64;
        hash = shifted - hash + c;
    }
    hash
}

fn pad_string(input: &str) -> String {
    let padding = 16 - (input.len() % 16);
    let mut out = String::with_capacity(input.len() + padding);
    out.push_str(input);
    let pad_ch = char::from_u32(padding as u32).unwrap_or('\u{10}');
    for _ in 0..padding {
        out.push(pad_ch);
    }
    out
}

fn string_to_word_array(input: &str) -> (Vec<i32>, usize) {
    let bytes = input.as_bytes();
    let mut words = vec![0i32; (bytes.len() + 3) / 4];
    for (i, &b) in bytes.iter().enumerate() {
        let shift = 24 - (i % 4) * 8;
        words[i / 4] |= (b as i32) << shift;
    }
    (words, bytes.len())
}

fn word_array_to_hex(array: &[i32], length: usize) -> String {
    let mut out = String::with_capacity(length * 2);
    for i in 0..length {
        let word = array[i / 4] as u32;
        let shift = 24 - (i % 4) * 8;
        let byte = ((word >> shift) & 0xff) as u8;
        out.push_str(&format!("{byte:02x}"));
    }
    out.to_uppercase()
}

fn encrypt_block(n: &mut [i32], offset: usize) {
    let prev: [i32; 4] = if offset == 0 {
        IV
    } else {
        [
            n[offset - 4],
            n[offset - 3],
            n[offset - 2],
            n[offset - 1],
        ]
    };
    for i in 0..4 {
        n[offset + i] ^= prev[i];
    }

    let mut s0 = n[offset] ^ RK[0];
    let mut s1 = n[offset + 1] ^ RK[1];
    let mut s2 = n[offset + 2] ^ RK[2];
    let mut s3 = n[offset + 3] ^ RK[3];
    let mut rki = 4usize;

    for _ in 1..10 {
        let t0 = T0[((s0 as u32) >> 24) as usize]
            ^ T1[(((s1 as u32) >> 16) & 255) as usize]
            ^ T2[(((s2 as u32) >> 8) & 255) as usize]
            ^ T3[((s3 as u32) & 255) as usize]
            ^ RK[rki];
        rki += 1;
        let t1 = T0[((s1 as u32) >> 24) as usize]
            ^ T1[(((s2 as u32) >> 16) & 255) as usize]
            ^ T2[(((s3 as u32) >> 8) & 255) as usize]
            ^ T3[((s0 as u32) & 255) as usize]
            ^ RK[rki];
        rki += 1;
        let t2 = T0[((s2 as u32) >> 24) as usize]
            ^ T1[(((s3 as u32) >> 16) & 255) as usize]
            ^ T2[(((s0 as u32) >> 8) & 255) as usize]
            ^ T3[((s1 as u32) & 255) as usize]
            ^ RK[rki];
        rki += 1;
        let t3 = T0[((s3 as u32) >> 24) as usize]
            ^ T1[(((s0 as u32) >> 16) & 255) as usize]
            ^ T2[(((s1 as u32) >> 8) & 255) as usize]
            ^ T3[((s2 as u32) & 255) as usize]
            ^ RK[rki];
        rki += 1;
        s0 = t0;
        s1 = t1;
        s2 = t2;
        s3 = t3;
    }

    let f0 = ((((SBOX[((s0 as u32) >> 24) as usize] as u32) << 24)
        | ((SBOX[(((s1 as u32) >> 16) & 255) as usize] as u32) << 16)
        | ((SBOX[(((s2 as u32) >> 8) & 255) as usize] as u32) << 8)
        | (SBOX[((s3 as u32) & 255) as usize] as u32)) as i32)
        ^ RK[rki];
    rki += 1;
    let f1 = ((((SBOX[((s1 as u32) >> 24) as usize] as u32) << 24)
        | ((SBOX[(((s2 as u32) >> 16) & 255) as usize] as u32) << 16)
        | ((SBOX[(((s3 as u32) >> 8) & 255) as usize] as u32) << 8)
        | (SBOX[((s0 as u32) & 255) as usize] as u32)) as i32)
        ^ RK[rki];
    rki += 1;
    let f2 = ((((SBOX[((s2 as u32) >> 24) as usize] as u32) << 24)
        | ((SBOX[(((s3 as u32) >> 16) & 255) as usize] as u32) << 16)
        | ((SBOX[(((s0 as u32) >> 8) & 255) as usize] as u32) << 8)
        | (SBOX[((s1 as u32) & 255) as usize] as u32)) as i32)
        ^ RK[rki];
    rki += 1;
    let f3 = ((((SBOX[((s3 as u32) >> 24) as usize] as u32) << 24)
        | ((SBOX[(((s0 as u32) >> 16) & 255) as usize] as u32) << 16)
        | ((SBOX[(((s1 as u32) >> 8) & 255) as usize] as u32) << 8)
        | (SBOX[((s2 as u32) & 255) as usize] as u32)) as i32)
        ^ RK[rki];

    n[offset] = f0;
    n[offset + 1] = f1;
    n[offset + 2] = f2;
    n[offset + 3] = f3;
}

fn process_block(n: &mut [i32]) {
    let mut i = 0;
    while i + 4 <= n.len() {
        encrypt_block(n, i);
        i += 4;
    }
}

/// Generate KissKH `kkey` for an episode id (video or subtitle endpoint).
pub fn generate_kkey(episode_id: i32, kind: KkeyKind) -> String {
    let guid = match kind {
        KkeyKind::Subtitle => SUB_GUID,
        KkeyKind::Video => VI_GUID,
    };
    let id_s = episode_id.to_string();
    let parts_before_hash = [
        "",
        id_s.as_str(),
        "", // null
        HASH,
        VERSION,
        guid,
        PLATFORM_VER,
        "kisskh",
        "kisskh",
        "kisskh",
        "kisskh",
        "kisskh",
        "kisskh",
        "00",
        "",
    ];
    let joined_for_hash = parts_before_hash.join("|");
    let hash_n = calculate_hash(&joined_for_hash);

    // After splice(1, 0, hash): ['', hash, id, null, hash_const, ...]
    let mut parts: Vec<String> = Vec::with_capacity(16);
    parts.push(String::new());
    parts.push(hash_n.to_string());
    parts.push(id_s);
    parts.push(String::new()); // null
    parts.push(HASH.to_string());
    parts.push(VERSION.to_string());
    parts.push(guid.to_string());
    parts.push(PLATFORM_VER.to_string());
    for _ in 0..3 {
        parts.push("kisskh".to_string());
    }
    for _ in 0..3 {
        parts.push("kisskh".to_string());
    }
    parts.push("00".to_string());
    parts.push(String::new());

    let padded = pad_string(&parts.join("|"));
    let (mut words, byte_len) = string_to_word_array(&padded);
    process_block(&mut words);
    word_array_to_hex(&words, byte_len)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn golden_episode_171699_video() {
        assert_eq!(
            generate_kkey(171699, KkeyKind::Video),
            "56697480CCBF13FF11E371C19696FBA7601E1C569630FF4001DBEBAB511F65357C5D712E4AD39F6E859770F5A0763B06E95ECB5142C0FE2DF561F722DB89E5F38D05E72CAA2FB6700380C17689688661D2D0631EDF1D579DF3127B9D313427CBD092C9B4D546EB6F69E2CA9760E02535750C1496D08C7C8937ACC42EE4B5334A"
        );
    }

    #[test]
    fn golden_episode_171699_sub() {
        assert_eq!(
            generate_kkey(171699, KkeyKind::Subtitle),
            "51703D792E47C1BE4F67C3C3B9D2170922646FB7E7DD9D41136987D391FDE6F342A591EB61C96DD496FE34E7642B61667E6C33C97D0F1BCA8F8381EFEB1B71EC78CDDA862771F65DB68703B5E707B05B383B3F176A57F681CA7413B96DC4E4CB525EBCFCB2F6500AC3491E092B093B482E123B59A758E23BC2261275F1C45747"
        );
    }

    #[test]
    fn golden_episode_1_video() {
        assert_eq!(
            generate_kkey(1, KkeyKind::Video),
            "23DC3EEF3D9B5DF88849AF476B008D4A58F9F3ACAB38A549C34AB3E473B7B3328BF080D795B810DF74E2DD76B6998B74CFA8BA86F6D6475708E88A44B762E3C576A1990EFFE4FF40291730B851812E47A89F38E89D57750449910D068F584D8C62EF5E91C838C93469EC3C4CF54D6C12A694E331B7A27040C722FA017BB6FCEC"
        );
    }
}
