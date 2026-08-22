//! CineJoy / api.shegu.st scrypt PoW — parity with Dart `EngineRuntime._solveScryptPow`.

use base64::Engine as _;
use sha2::{Digest, Sha256};

pub fn solve_scrypt_pow_json(payload: &str) -> String {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(payload) else {
        return String::new();
    };
    let s = v.get("s").and_then(|x| x.as_str()).unwrap_or("");
    let b = v.get("b").and_then(|x| x.as_str()).unwrap_or("");
    let n = v.get("n").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
    let r = v.get("r").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
    let p = v.get("p").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
    let d = v.get("d").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
    if s.is_empty() || b.is_empty() || n == 0 || r == 0 || p == 0 || d == 0 {
        return String::new();
    }
    if !n.is_power_of_two() {
        return String::new();
    }
    let log_n = n.trailing_zeros() as u8;
    let max = v
        .get("max")
        .and_then(|x| x.as_u64())
        .unwrap_or(500_000)
        .clamp(1, 500_000) as u32;

    let salt_input = format!("pow2-salt|{s}|{b}");
    let salt = Sha256::digest(salt_input.as_bytes());

    let params = match scrypt::Params::new(log_n, r, p, 32) {
        Ok(p) => p,
        Err(_) => return String::new(),
    };

    for counter in 0..max {
        if counter % 256 == 0
            && (utils::engine_cancel::cancellation_token().is_cancelled()
                || utils::engine_cancel::is_shutdown_requested())
        {
            return String::new();
        }
        let password = format!("pow2|{b}|{s}|{counter}");
        let mut out = [0u8; 32];
        if scrypt::scrypt(password.as_bytes(), &salt, &params, &mut out).is_err() {
            return String::new();
        }
        if leading_zero_bits(&out) >= d {
            let mut payload = v.clone();
            if let Some(obj) = payload.as_object_mut() {
                obj.insert("c".into(), serde_json::json!(counter));
            }
            let raw = payload.to_string();
            return base64::engine::general_purpose::STANDARD.encode(raw.as_bytes());
        }
    }
    String::new()
}

/// Same bit-count as Dart `_leadingZeroBits` (MSB-first per byte).
fn leading_zero_bits(data: &[u8]) -> u32 {
    let mut count = 0u32;
    for &value in data {
        if value == 0 {
            count += 8;
            continue;
        }
        let mut bits = 0u32;
        let mut v = value;
        while v > 0 {
            bits += 1;
            v >>= 1;
        }
        count += 8 - bits;
        break;
    }
    count
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_nonce_small_params() {
        let challenge = serde_json::json!({
            "s": "salt",
            "b": "blob",
            "n": 16,
            "r": 1,
            "p": 1,
            "d": 1,
            "max": 5000
        });
        let out = solve_scrypt_pow_json(&challenge.to_string());
        assert!(!out.is_empty(), "expected a solution");
        let raw = String::from_utf8(
            base64::engine::general_purpose::STANDARD
                .decode(&out)
                .unwrap(),
        )
        .unwrap();
        let v: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert!(v.get("c").and_then(|c| c.as_u64()).is_some());
    }

    #[test]
    fn leading_zeros_empty_msb() {
        assert_eq!(leading_zero_bits(&[0, 0, 0x80]), 16);
        assert_eq!(leading_zero_bits(&[0x40]), 1);
        assert_eq!(leading_zero_bits(&[0xff]), 0);
    }
}
