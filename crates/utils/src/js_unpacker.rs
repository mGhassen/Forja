use regex::Regex;
use std::sync::LazyLock;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum UnpackError {
    #[error("No p,a,c,k,e,d string found")]
    NotFound,
    #[error("Symtab length mismatch")]
    SymtabMismatch,
}

static PACKED: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"\}\s*\(\s*'([^']+)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([^']+)'\.split\('\|'\)\s*,\s*\d+\s*,\s*(?:\{\}|null)\s*\)\s*\)",
    )
    .unwrap()
});

static EVAL: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"eval\(function\(p,a,c,k,e,d\).*?\)\)").unwrap()
});

fn unescape(s: &str) -> String {
    s.replace(r"\\", "\\")
        .replace(r"\'", "'")
        .replace(r#"\""#, "\"")
}

fn unbase(word: &str, radix: u32) -> String {
    if radix <= 10 {
        return u32::from_str_radix(word, radix).map(|n| n.to_string()).unwrap_or_else(|_| word.to_string());
    }
    let mut n: u32 = 0;
    for c in word.chars() {
        let d = match c {
            '0'..='9' => c as u32 - '0' as u32,
            'a'..='z' => c as u32 - 'a' as u32 + 10,
            'A'..='Z' => c as u32 - 'A' as u32 + 36,
            _ => 0,
        };
        n = n * radix + d;
    }
    n.to_string()
}

pub fn unpack(source: &str) -> Result<String, UnpackError> {
    let caps = PACKED.captures(source).ok_or(UnpackError::NotFound)?;
    let payload = unescape(caps.get(1).unwrap().as_str());
    let radix: u32 = caps.get(2).unwrap().as_str().parse().unwrap_or(36);
    let count: usize = caps.get(3).unwrap().as_str().parse().unwrap_or(0);
    let symtab: Vec<&str> = caps.get(4).unwrap().as_str().split('|').collect();
    if symtab.len() != count {
        return Err(UnpackError::SymtabMismatch);
    }

    let word_re = Regex::new(r"\b\w+\b").unwrap();
    let result = word_re.replace_all(&payload, |caps: &regex::Captures| {
        let word = &caps[0];
        if let Ok(idx) = unbase(word, radix).parse::<usize>() {
            if idx < count {
                let repl = symtab[idx];
                if repl.is_empty() {
                    return word.to_string();
                }
                return repl.to_string();
            }
        }
        word.to_string()
    });
    Ok(result.into_owned())
}

pub fn unpack_eval(html: &str) -> Result<String, UnpackError> {
    let m = EVAL.find(html).ok_or(UnpackError::NotFound)?;
    unpack(m.as_str())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_missing_packed() {
        assert!(unpack("no packed js here").is_err());
    }

    #[test]
    fn unpacks_simple_payload() {
        let packed = "eval(function(p,a,c,k,e,d){}('0 1',10,2,'hello|world'.split('|'),0,{}))";
        let out = unpack(packed).unwrap();
        assert_eq!(out, "hello world");
    }
}
