///|
fn valid_pain001_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr>
  #|      <MsgId>MSG-001</MsgId>
  #|      <CreDtTm>2026-10-08T12:00:00Z</CreDtTm>
  #|      <NbOfTxs>2</NbOfTxs>
  #|    </GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-001</PmtInfId>
  #|      <ReqdExctnDt>2026-10-10</ReqdExctnDt>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-001</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">100.00</InstdAmt></Amt>
  #|      </CdtTrfTxInf>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-002</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">250.00</InstdAmt></Amt>
  #|      </CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  xml
}

///|
fn invalid_pain001_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr>
  #|      <MsgId></MsgId>
  #|    </GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-001</PmtInfId>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-DUP</EndToEndId></PmtId>
  #|      </CdtTrfTxInf>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-DUP</EndToEndId></PmtId>
  #|      </CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  xml
}

///|
test "valid pain.001 passes milestone rules" {
  let report = @mooniso_lite.validate_pain001(valid_pain001_xml())
  assert_true(report.is_valid())
  assert_eq(report.summary.payment_instruction_count, 1)
  assert_eq(report.summary.transaction_count, 2)
}

///|
test "invalid pain.001 reports required-field and duplicate issues" {
  let report = @mooniso_lite.validate_pain001(invalid_pain001_xml())
  assert_false(report.is_valid())
  assert_true(report.diagnostics.length() >= 6)
}

///|
test "validation report supports json and markdown" {
  let report = @mooniso_lite.validate_pain001(valid_pain001_xml())
  assert_true(report.to_json().contains("\"valid\": true"))
  assert_true(report.to_markdown().contains("**Result:** VALID"))
}

///|
fn invalid_format_pain001_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr>
  #|      <MsgId>MSG-FORMAT</MsgId>
  #|      <CreDtTm>08-10-2026 12:00</CreDtTm>
  #|      <NbOfTxs>many</NbOfTxs>
  #|    </GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-FORMAT</PmtInfId>
  #|      <ReqdExctnDt>10/10/2026</ReqdExctnDt>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-FORMAT-1</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="eur">not-a-number</InstdAmt></Amt>
  #|      </CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  xml
}

///|
test "format validation catches invalid values" {
  let report = @mooniso_lite.validate_pain001(invalid_format_pain001_xml())
  assert_false(report.is_valid())
  assert_true(report.diagnostics.length() >= 5)
}
