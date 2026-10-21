///|
test "xml reader decodes entities in attributes" {
  let reader = @moonpay_flow.XmlReader::from_string(
    "<root a=\"A&amp;B\" b='x&#x41;'/>",
  )
  match reader.read_event().kind {
    Empty(element) => {
      assert_eq(element.get("a").unwrap(), "A&B")
      assert_eq(element.get("b").unwrap(), "xA")
    }
    _ => fail("expected empty element")
  }
}

///|
test "xml reader flattens nested paths" {
  let fields = @moonpay_flow.flatten_xml(
    "<root><outer><inner>value</inner></outer></root>",
  )
  let values = @moonpay_flow.texts_by_suffix(fields, "/outer/inner")
  assert_eq(values.length(), 1)
  assert_eq(values[0], "value")
}

///|
test "xml reader rejects unclosed root" {
  let reader = @moonpay_flow.XmlReader::from_string("<root>")
  let _ = reader.read_event()
  let failed = try {
    let _ = reader.read_event()
    false
  } catch {
    @moonpay_flow.XmlParseError(_) => true
  }
  assert_true(failed)
}

///|
test "xml reader rejects trailing content" {
  let reader = @moonpay_flow.XmlReader::from_string("<root/>tail")
  let _ = reader.read_event()
  let failed = try {
    let _ = reader.read_event()
    false
  } catch {
    @moonpay_flow.XmlParseError(_) => true
  }
  assert_true(failed)
}

///|
test "xml reader skips declaration comments and processing instructions" {
  let reader = @moonpay_flow.XmlReader::from_string(
    "<?xml version=\"1.0\"?><!-- comment --><?pi ok?><root/>",
  )
  match reader.read_event().kind {
    Empty(element) => assert_eq(element.name, "root")
    _ => fail("expected root empty element")
  }
}
