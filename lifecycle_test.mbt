///|
test "lifecycle classification covers payment states and orphans" {
  let pain = @fs.read_file_to_string("fixtures/lifecycle_pain001.xml")
  let status = @fs.read_file_to_string("fixtures/lifecycle_pain002.xml")
  let statement = @fs.read_file_to_string("fixtures/lifecycle_camt053.xml")
  let report = @moonpay_flow.lifecycle_report(pain, status, statement)
  assert_eq(report.cases.length(), 9)
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
  assert_eq(states.get("TX-FULL-REFUND").unwrap(), "FULLY_REFUNDED")
  assert_eq(states.get("TX-PARTIAL-REFUND").unwrap(), "PARTIALLY_REFUNDED")
  assert_eq(report.orphan_statuses.length(), 1)
  assert_eq(report.orphan_statements.length(), 1)
  assert_true(report.to_json().contains("SETTLED_NOT_POSTED"))
}


///|
test "lifecycle checks debtor and creditor account ownership" {
  let pain =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn><GrpHdr><MsgId>OWN-1</MsgId><CreDtTm>2026-10-21T08:00:00Z</CreDtTm><NbOfTxs>1</NbOfTxs><CtrlSum>10.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>OWN-P1</PmtInfId><ReqdExctnDt>2026-10-21</ReqdExctnDt>
  #|      <DbtrAcct><Id><IBAN>DE89370400440532013000</IBAN></Id></DbtrAcct>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>OWN-TX</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt><CdtrAcct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></CdtrAcct></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let status =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>OWN-S1</MsgId><CreDtTm>2026-10-21T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>OWN-TX</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let statement =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  #|  <BkToCstmrStmt><GrpHdr><MsgId>OWN-C1</MsgId><CreDtTm>2026-10-21T10:00:00Z</CreDtTm></GrpHdr>
  #|    <Stmt><Id>OWN-ST</Id><Acct><Id><IBAN>GB82WEST12345698765432</IBAN></Id></Acct>
  #|      <Ntry><CdtDbtInd>DBIT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>OWN-TX</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|    </Stmt>
  #|  </BkToCstmrStmt>
  #|</Document>
  let report = @moonpay_flow.lifecycle_report(pain, status, statement)
  assert_eq(report.cases.length(), 1)
  assert_eq(report.cases[0].state.name(), "ACCOUNT_UNMATCHED")
}

///|
test "lifecycle accepts normal creditor account credit" {
  let pain =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn><GrpHdr><MsgId>CRED-1</MsgId><CreDtTm>2026-10-21T08:00:00Z</CreDtTm><NbOfTxs>1</NbOfTxs><CtrlSum>10.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>CRED-P1</PmtInfId><ReqdExctnDt>2026-10-21</ReqdExctnDt>
  #|      <DbtrAcct><Id><IBAN>DE89370400440532013000</IBAN></Id></DbtrAcct>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>CRED-TX</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt><CdtrAcct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></CdtrAcct></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let status =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>CRED-S1</MsgId><CreDtTm>2026-10-21T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>CRED-TX</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let statement =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  #|  <BkToCstmrStmt><GrpHdr><MsgId>CRED-C1</MsgId><CreDtTm>2026-10-21T10:00:00Z</CreDtTm></GrpHdr>
  #|    <Stmt><Id>CRED-ST</Id><Acct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></Acct>
  #|      <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>CRED-TX</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|    </Stmt>
  #|  </BkToCstmrStmt>
  #|</Document>
  let report = @moonpay_flow.lifecycle_report(pain, status, statement)
  assert_eq(report.cases.length(), 1)
  assert_eq(report.cases[0].state.name(), "SETTLED")
  assert_eq(report.cases[0].statement_role, "CREDITOR")
}
