static FLAGS: &[(&str, &str)] = &[
    ("multi", "🌐"),
    ("al", "🇦🇱"),
    ("ar", "🇸🇦"),
    ("bg", "🇧🇬"),
    ("bl", "🇮🇳"),
    ("cs", "🇨🇿"),
    ("de", "🇩🇪"),
    ("el", "🇬🇷"),
    ("en", "🇺🇸"),
    ("es", "🇪🇸"),
    ("et", "🇪🇪"),
    ("fa", "🇮🇷"),
    ("fr", "🇫🇷"),
    ("gu", "🇮🇳"),
    ("he", "🇮🇱"),
    ("hi", "🇮🇳"),
    ("hr", "🇭🇷"),
    ("hu", "🇭🇺"),
    ("id", "🇮🇩"),
    ("it", "🇮🇹"),
    ("ja", "🇯🇵"),
    ("kn", "🇮🇳"),
    ("ko", "🇰🇷"),
    ("lt", "🇱🇹"),
    ("lv", "🇱🇻"),
    ("ml", "🇮🇳"),
    ("mr", "🇮🇳"),
    ("mx", "🇲🇽"),
    ("nl", "🇳🇱"),
    ("no", "🇳🇴"),
    ("pa", "🇮🇳"),
    ("pl", "🇵🇱"),
    ("pt", "🇧🇷"),
    ("ro", "🇷🇴"),
    ("ru", "🇷🇺"),
    ("sk", "🇸🇰"),
    ("sl", "🇸🇮"),
    ("sr", "🇷🇸"),
    ("ta", "🇮🇳"),
    ("te", "🇮🇳"),
    ("th", "🇹🇭"),
    ("tr", "🇹🇷"),
    ("uk", "🇺🇦"),
    ("vi", "🇻🇳"),
    ("zh", "🇨🇳"),
];

static LANG_NAMES: &[(&str, &str)] = &[
    ("multi", "Multi"),
    ("al", "Albanian"),
    ("ar", "Arabic"),
    ("bg", "Bulgarian"),
    ("bl", "Bengali"),
    ("cs", "Czech"),
    ("de", "German"),
    ("el", "Greek"),
    ("en", "English"),
    ("es", "Castilian Spanish"),
    ("et", "Estonian"),
    ("fa", "Persian"),
    ("fr", "French"),
    ("gu", "Gujarati"),
    ("he", "Hebrew"),
    ("hi", "Hindi"),
    ("hr", "Croatian"),
    ("hu", "Hungarian"),
    ("id", "Indonesian"),
    ("it", "Italian"),
    ("ja", "Japanese"),
    ("kn", "Kannada"),
    ("ko", "Korean"),
    ("lt", "Lithuanian"),
    ("lv", "Latvian"),
    ("ml", "Malayalam"),
    ("mr", "Marathi"),
    ("mx", "Latin American Spanish"),
    ("nl", "Dutch"),
    ("no", "Norwegian"),
    ("pa", "Punjabi"),
    ("pl", "Polish"),
    ("pt", "Portuguese"),
    ("ro", "Romanian"),
    ("ru", "Russian"),
    ("sk", "Slovak"),
    ("sl", "Slovenian"),
    ("sr", "Serbian"),
    ("ta", "Tamil"),
    ("te", "Telugu"),
    ("th", "Thai"),
    ("tr", "Turkish"),
    ("uk", "Ukrainian"),
    ("vi", "Vietnamese"),
    ("zh", "Chinese"),
];

pub fn flag_from_country_code(code: &str) -> &'static str {
    FLAGS
        .iter()
        .find(|(k, _)| *k == code)
        .map(|(_, f)| *f)
        .unwrap_or("")
}

pub fn find_country_codes(value: &str) -> Vec<String> {
    let mut out = Vec::new();
    for (code, name) in LANG_NAMES {
        if value.contains(name) && !out.iter().any(|c| c == code) {
            out.push((*code).to_string());
        }
    }
    out
}

pub fn country_flags(codes: &[String]) -> String {
    codes
        .iter()
        .map(|c| flag_from_country_code(c))
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_german_in_title() {
        let codes = find_country_codes("German Dub 1080p");
        assert!(codes.contains(&"de".to_string()));
    }
}
