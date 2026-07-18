//! Catalog region heuristics for IPTV pool tagging (RFC-040).
//! Not geo-IP — timezone + category/channel name tokens.

use serde::Serialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct RegionGuess {
    pub primary: String,
    pub tags: Vec<String>,
    pub confidence: f32,
}

/// Classify from Xtream `server_info.timezone` and optional category names.
pub fn classify_region(timezone: Option<&str>, category_names: &[String]) -> RegionGuess {
    let mut scores: HashMap<&'static str, f32> = HashMap::new();

    if let Some(tz) = timezone {
        bump_timezone(&mut scores, tz);
    }
    for name in category_names {
        bump_label(&mut scores, name);
    }

    if scores.is_empty() {
        return RegionGuess {
            primary: "UNKNOWN".into(),
            tags: vec![],
            confidence: 0.0,
        };
    }

    let mut ranked: Vec<_> = scores.into_iter().collect();
    ranked.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    let total: f32 = ranked.iter().map(|(_, s)| *s).sum::<f32>().max(0.001);
    let (primary, top) = ranked[0];
    let confidence = (top / total).clamp(0.0, 1.0);

    let tags: Vec<String> = ranked
        .iter()
        .filter(|(_, s)| *s >= 1.0)
        .map(|(k, _)| (*k).to_string())
        .collect();

    let primary = if confidence < 0.45 && tags.len() > 1 {
        "MIXED".to_string()
    } else {
        primary.to_string()
    };

    RegionGuess {
        primary,
        tags,
        confidence,
    }
}

fn bump_timezone(scores: &mut HashMap<&'static str, f32>, tz: &str) {
    let t = tz.to_lowercase();
    if t.contains("istanbul") || t.contains("europe/istanbul") {
        *scores.entry("TR").or_default() += 3.0;
    } else if t.contains("london") || t.contains("dublin") {
        *scores.entry("UK").or_default() += 3.0;
    } else if t.contains("new_york")
        || t.contains("chicago")
        || t.contains("los_angeles")
        || t.contains("denver")
        || t.contains("america/")
    {
        *scores.entry("US").or_default() += 2.5;
    } else if t.contains("europe/") {
        *scores.entry("EU").or_default() += 2.0;
    } else if t.contains("africa/casablanca") || t.contains("africa/tunis") {
        *scores.entry("EU").or_default() += 1.0;
        *scores.entry("MENA").or_default() += 1.5;
    }
}

fn token_hit(s: &str, code: &str) -> bool {
    s.split(|c: char| !c.is_ascii_alphanumeric())
        .any(|t| t == code)
}

fn bump_label(scores: &mut HashMap<&'static str, f32>, raw: &str) {
    let s = raw.to_uppercase();
    let checks: &[(&str, &str, f32)] = &[
        ("TR", r"\bTR\b|TURK|TÜRK|TURKIYE|TURKEY|│TR│|\[TR\]", 2.0),
        ("UK", r"\bUK\b|BRITAIN|BRITISH|│UK│|\[UK\]", 2.0),
        ("US", r"\bUS\b|USA\b|UNITED STATES|│US│|\[US\]|NFL|NBA", 2.0),
        ("DE", r"\bDE\b|GERMAN|DEUTSCH|│DE│|\[DE\]", 1.5),
        ("FR", r"\bFR\b|FRENCH|FRANCE|│FR│|\[FR\]", 1.5),
        ("IT", r"\bIT\b|ITALY|ITALIAN|│IT│|\[IT\]", 1.5),
        ("NL", r"\bNL\b|DUTCH|NETHERLANDS|│NL│", 1.5),
        ("ES", r"\bES\b|SPAIN|SPANISH|│ES│", 1.5),
        ("AR", r"ARAB|العرب|│AR│|\[AR\]|MENA", 1.5),
    ];
    for (code, _pat, w) in checks {
        // Simple contains heuristics (avoid pulling regex into hot path for every token).
        let hit = match *code {
            "TR" => token_hit(&s, "TR")
                || s.contains("TURK")
                || s.contains("TÜRK")
                || s.contains("TURKIYE")
                || s.contains("TURKEY"),
            "UK" => token_hit(&s, "UK") || s.contains("BRITAIN") || s.contains("BRITISH"),
            "US" => {
                token_hit(&s, "US")
                    || s.contains("USA")
                    || s.contains("UNITED STATES")
                    || token_hit(&s, "NFL")
                    || token_hit(&s, "NBA")
            }
            "DE" => {
                token_hit(&s, "DE") || s.contains("GERMAN") || s.contains("DEUTSCH")
            }
            "FR" => {
                token_hit(&s, "FR") || s.contains("FRENCH") || s.contains("FRANCE")
            }
            "IT" => {
                token_hit(&s, "IT") || s.contains("ITALY") || s.contains("ITALIAN")
            }
            "NL" => {
                token_hit(&s, "NL") || s.contains("DUTCH") || s.contains("NETHERLANDS")
            }
            "ES" => {
                token_hit(&s, "ES") || s.contains("SPAIN") || s.contains("SPANISH")
            }
            "AR" => s.contains("ARAB") || s.contains("MENA") || token_hit(&s, "AR"),
            _ => false,
        };
        if hit {
            *scores.entry(code).or_default() += w;
            if matches!(*code, "DE" | "FR" | "IT" | "NL" | "ES") {
                *scores.entry("EU").or_default() += 0.5;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn istanbul_timezone_is_tr() {
        let g = classify_region(Some("Europe/Istanbul"), &[]);
        assert_eq!(g.primary, "TR");
        assert!(g.confidence > 0.5);
    }

    #[test]
    fn us_categories() {
        let cats = vec!["USA | Sports".into(), "US Movies".into(), "VIP".into()];
        let g = classify_region(None, &cats);
        assert_eq!(g.primary, "US");
    }

    #[test]
    fn multi_region_tags() {
        let cats = vec![
            "TR | Haber".into(),
            "UK | BBC".into(),
            "US | ABC".into(),
            "DE | Sport".into(),
        ];
        let g = classify_region(None, &cats);
        assert!(
            g.tags.len() >= 2 || g.primary == "MIXED",
            "got primary={} tags={:?}",
            g.primary,
            g.tags
        );
    }
}
