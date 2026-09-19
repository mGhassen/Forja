//! Generic scrypt KDF for pack scripts (`ctx.crypto.scrypt`). Packs own PoW loops.

/// JSON in: `{ password, salt? | saltHex?, n, r, p, dkLen? }` → hex derived key (empty on error).
pub fn scrypt_bridge_json(payload: &str) -> String {
    if utils::engine_cancel::cancellation_token().is_cancelled()
        || utils::engine_cancel::is_shutdown_requested()
    {
        return String::new();
    }
    let Ok(v) = serde_json::from_str::<serde_json::Value>(payload) else {
        return String::new();
    };
    let password = v.get("password").and_then(|x| x.as_str()).unwrap_or("");
    let n = v.get("n").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
    let r = v.get("r").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
    let p = v.get("p").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
    let dk_len = v
        .get("dkLen")
        .or_else(|| v.get("dklen"))
        .and_then(|x| x.as_u64())
        .unwrap_or(32)
        .clamp(1, 64) as usize;
    if password.is_empty() || n == 0 || r == 0 || p == 0 || !n.is_power_of_two() {
        return String::new();
    }
    let log_n = n.trailing_zeros() as u8;
    let salt = if let Some(hex) = v.get("saltHex").and_then(|x| x.as_str()) {
        match crate::crypto_host::bytes_from_hex(hex) {
            Ok(b) if !b.is_empty() => b,
            _ => return String::new(),
        }
    } else if let Some(s) = v.get("salt").and_then(|x| x.as_str()) {
        s.as_bytes().to_vec()
    } else {
        return String::new();
    };

    let params = match scrypt::Params::new(log_n, r, p, dk_len) {
        Ok(p) => p,
        Err(_) => return String::new(),
    };
    let mut out = vec![0u8; dk_len];
    if scrypt::scrypt(password.as_bytes(), &salt, &params, &mut out).is_err() {
        return String::new();
    }
    crate::crypto_host::hex_from_bytes(&out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scrypt_known_vector_small() {
        let payload = serde_json::json!({
            "password": "password",
            "salt": "NaCl",
            "n": 16,
            "r": 1,
            "p": 1,
            "dkLen": 32
        });
        let a = scrypt_bridge_json(&payload.to_string());
        let b = scrypt_bridge_json(&payload.to_string());
        assert_eq!(a.len(), 64);
        assert_eq!(a, b);
    }
}
