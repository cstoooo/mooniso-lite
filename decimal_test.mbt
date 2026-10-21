///|
test "decimal parses supported values" {
  match @moonpay_flow.Decimal::parse("123.45") {
    Some(value) => assert_eq(value.to_string(), "123.45")
    None => fail("expected decimal to parse")
  }
  match @moonpay_flow.Decimal::parse("7") {
    Some(value) => assert_eq(value.to_string(), "7.00")
    None => fail("expected integer decimal to parse")
  }
  match @moonpay_flow.Decimal::parse("1.2") {
    Some(value) => assert_eq(value.to_string(), "1.20")
    None => fail("expected one-fraction decimal to parse")
  }
}

///|
test "decimal rejects invalid values" {
  assert_true(@moonpay_flow.Decimal::parse("") is None)
  assert_true(@moonpay_flow.Decimal::parse("1.234") is None)
  assert_true(@moonpay_flow.Decimal::parse("1..2") is None)
  assert_true(@moonpay_flow.Decimal::parse("abc") is None)
}

///|
test "decimal adds and compares values" {
  let left = @moonpay_flow.Decimal::parse("10.25").unwrap()
  let right = @moonpay_flow.Decimal::parse("2.75").unwrap()
  assert_eq(left.add(right).to_string(), "13.00")
  assert_eq(left.compare(right), 1)
  assert_eq(right.compare(left), -1)
  assert_eq(left.compare(left), 0)
}
