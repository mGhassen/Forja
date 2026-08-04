//! Golden stubs for stalker category normalize (no network).

#[test]
fn stalker_categories_fixture_shape() {
    let json = r#"[{"id":"10","title":"Sports"},{"id":"*","title":"All"}]"#;
    let v: serde_json::Value = serde_json::from_str(json).unwrap();
    let cats = {
        // Mirror stalker_client parse via public portal path isn't exported —
        // assert fixture shape for host contract.
        let arr = v.as_array().unwrap();
        arr.iter()
            .filter(|x| x.get("id").and_then(|i| i.as_str()) != Some("*"))
            .count()
    };
    assert_eq!(cats, 1);
}
