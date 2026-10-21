///|
test "decimal parse and format roundtrip" {
  let values = ["0", "1", "1.2", "12.34", "999.99", "0007.05"]
  for value in values {
    let parsed = @moonpay_flow.Decimal::parse(value).unwrap()
    let reparsed = @moonpay_flow.Decimal::parse(parsed.to_string()).unwrap()
    assert_eq(parsed.compare(reparsed), 0)
  }
}

///|
test "decimal addition is commutative" {
  let pairs = [("10.25", "2.75"), ("1.20", "0.80"), ("99.99", "0.01")]
  for pair in pairs {
    let left = @moonpay_flow.Decimal::parse(pair.0).unwrap()
    let right = @moonpay_flow.Decimal::parse(pair.1).unwrap()
    assert_eq(left.add(right).to_string(), right.add(left).to_string())
  }
}

///|
test "flatten xml roundtrips escaped text" {
  let fields = @moonpay_flow.flatten_xml("<root><value>A &amp; B</value></root>")
  let values = @moonpay_flow.texts_by_suffix(fields, "/value")
  assert_eq(values.length(), 1)
  assert_eq(values[0], "A & B")
}
