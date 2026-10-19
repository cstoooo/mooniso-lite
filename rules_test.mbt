///|
test "rule catalog has unique codes" {
  let rules = @mooniso_lite.rule_catalog()
  assert_true(rules.length() >= 40)
  let seen : Map[String, Bool] = Map([])
  for rule in rules {
    assert_false(seen.contains(rule.code))
    seen.set(rule.code, true)
    assert_true(rule.description != "")
  }
}
