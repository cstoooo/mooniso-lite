///|
test "fixtures match expected message type and validity" {
  let cases : Array[(String, @mooniso_lite.MessageKind, Bool)] = [
    ("fixtures/valid_pain001.xml", @mooniso_lite.MessageKind::Pain001, true),
    ("fixtures/invalid_pain001.xml", @mooniso_lite.MessageKind::Pain001, false),
    ("fixtures/invalid_format_pain001.xml", @mooniso_lite.MessageKind::Pain001, false),
    ("fixtures/invalid_control_sum_pain001.xml", @mooniso_lite.MessageKind::Pain001, false),
    ("fixtures/invalid_identity_pain001.xml", @mooniso_lite.MessageKind::Pain001, false),
    ("fixtures/valid_pain002.xml", @mooniso_lite.MessageKind::Pain002, true),
    ("fixtures/valid_pacs008.xml", @mooniso_lite.MessageKind::Pacs008, true),
    ("fixtures/valid_pacs002.xml", @mooniso_lite.MessageKind::Pacs002, true),
    ("fixtures/valid_camt053.xml", @mooniso_lite.MessageKind::Camt053, true),
  ]
  for item in cases {
    let path = item.0
    let expected_kind = item.1
    let expected_valid = item.2
    let xml = @fs.read_file_to_string(path)
    let report = @mooniso_lite.validate_message(xml)
    assert_eq(report.info.kind.name(), expected_kind.name())
    assert_eq(report.is_valid(), expected_valid)
  }
}
