use webstreamr::config;
use webstreamr::utils::get_closest_resolution;

#[test]
fn closest_resolution_matches_dart() {
    assert_eq!(get_closest_resolution(Some(1080)), "1080p");
    assert_eq!(get_closest_resolution(Some(900)), "1080p");
    assert_eq!(get_closest_resolution(None), "Unknown");
}

#[test]
fn config_helpers() {
    let mut c = config::default_config();
    c.insert("excludeResolution_720p".into(), "on".into());
    assert!(config::is_resolution_excluded(&c, "720p"));
}
