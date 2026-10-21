///|
test "xml reader parses element attributes and text" {
  let reader = @moonpay_flow.XmlReader::from_string("<root id=\"1\">hello</root>")
  match reader.read_event().kind {
    Start(element) => {
      assert_eq(element.name, "root")
      match element.get("id") {
        Some(value) => assert_eq(value, "1")
        None => fail("missing id attribute")
      }
    }
    _ => fail("expected start event")
  }
  match reader.read_event().kind {
    Text(text) => assert_eq(text, "hello")
    _ => fail("expected text event")
  }
  match reader.read_event().kind {
    End(name) => assert_eq(name, "root")
    _ => fail("expected end event")
  }
  match reader.read_event().kind {
    Eof => ()
    _ => fail("expected eof")
  }
}

///|
test "xml reader decodes entities and skips comments" {
  let reader = @moonpay_flow.XmlReader::from_string(
    "<root><!-- note -->A &amp; B &#65;</root>",
  )
  let _ = reader.read_event()
  match reader.read_event().kind {
    Text(text) => assert_eq(text, "A & B A")
    _ => fail("expected decoded text event")
  }
}

///|
test "xml reader parses self closing and cdata" {
  let reader = @moonpay_flow.XmlReader::from_string("<root><item/><![CDATA[x<y]]></root>")
  match reader.read_event().kind {
    Start(name) => assert_eq(name.name, "root")
    _ => fail("expected root start")
  }
  match reader.read_event().kind {
    Empty(element) => assert_eq(element.name, "item")
    _ => fail("expected empty item")
  }
  match reader.read_event().kind {
    Text(text) => assert_eq(text, "x<y")
    _ => fail("expected cdata text")
  }
}

///|
test "xml reader rejects mismatched tags" {
  let reader = @moonpay_flow.XmlReader::from_string("<a></b>")
  let _ = reader.read_event()
  let failed = try {
    let _ = reader.read_event()
    false
  } catch {
    @moonpay_flow.XmlParseError(_) => true
  }
  assert_true(failed)
}
