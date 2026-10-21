///|
test "decimal handles zero and leading zeros" {
  assert_eq(@moonpay_flow.Decimal::zero().to_string(), "0.00")
  assert_eq(@moonpay_flow.Decimal::parse("0001.2").unwrap().to_string(), "1.20")
  assert_eq(@moonpay_flow.Decimal::parse("0000").unwrap().to_string(), "0.00")
}

///|
test "decimal rejects signs whitespace and malformed separators" {
  assert_true(@moonpay_flow.Decimal::parse("-1.00") is None)
  assert_true(@moonpay_flow.Decimal::parse("+1.00") is None)
  assert_true(@moonpay_flow.Decimal::parse(" 1.00") is None)
  assert_true(@moonpay_flow.Decimal::parse("1.00 ") is None)
  assert_true(@moonpay_flow.Decimal::parse("1,00") is None)
}
