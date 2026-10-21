///|
test "lifecycle classification covers payment states and orphans" {
  let pain = @fs.read_file_to_string("fixtures/lifecycle_pain001.xml")
  let status = @fs.read_file_to_string("fixtures/lifecycle_pain002.xml")
  let statement = @fs.read_file_to_string("fixtures/lifecycle_camt053.xml")
  let report = @moonpay_flow.lifecycle_report(pain, status, statement)
  assert_eq(report.cases.length(), 7)
  let states : Map[String, String] = Map([])
  for case in report.cases {
    states.set(case.end_to_end_id, case.state.name())
    assert_true(case.action != "")
  }
  assert_eq(states.get("TX-SETTLED").unwrap(), "SETTLED")
  assert_eq(states.get("TX-NOT-POSTED").unwrap(), "SETTLED_NOT_POSTED")
  assert_eq(states.get("TX-REJECTED").unwrap(), "REJECTED")
  assert_eq(states.get("TX-PENDING").unwrap(), "PENDING")
  assert_eq(states.get("TX-MISMATCH").unwrap(), "STATEMENT_MISMATCH")
  assert_eq(states.get("TX-BEFORE-FINAL").unwrap(), "STATEMENT_BEFORE_FINAL_STATUS")
  assert_eq(states.get("TX-NO-STATUS").unwrap(), "MISSING_STATUS")
  assert_eq(report.orphan_statuses.length(), 1)
  assert_eq(report.orphan_statements.length(), 1)
  assert_true(report.to_json().contains("SETTLED_NOT_POSTED"))
}
