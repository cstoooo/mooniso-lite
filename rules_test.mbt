///|
test "rule catalog has unique codes" {
  let rules = @moonpay_flow.rule_catalog()
  assert_true(rules.length() >= 60)
  let seen : Map[String, Bool] = Map([])
  for rule in rules {
    assert_false(seen.contains(rule.code))
    seen.set(rule.code, true)
    assert_true(rule.description != "")
  }
}
