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
  #|      <CtrlSum>350.00</CtrlSum>
  #|    </GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-001</PmtInfId>
  #|      <PmtMtd>TRF</PmtMtd>
  #|      <ChrgBr>SLEV</ChrgBr>
  #|      <ReqdExctnDt>2026-10-10</ReqdExctnDt>
  #|      <DbtrAgt><FinInstnId><BIC>DEUTDEFF</BIC></FinInstnId></DbtrAgt>
  #|      <DbtrAcct><Id><IBAN>DE89370400440532013000</IBAN></Id></DbtrAcct>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-001</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">100.00</InstdAmt></Amt>
  #|        <CdtrAgt><FinInstnId><BIC>BNPAFRPPXXX</BIC></FinInstnId></CdtrAgt>
  #|        <CdtrAcct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></CdtrAcct>
  #|      </CdtTrfTxInf>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-002</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">250.00</InstdAmt></Amt>
  #|        <CdtrAgt><FinInstnId><BIC>BNPAFRPPXXX</BIC></FinInstnId></CdtrAgt>
  #|        <CdtrAcct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></CdtrAcct>
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
  let report = @moonpay_flow.validate_pain001(valid_pain001_xml())
  assert_true(report.is_valid())
  assert_eq(report.summary.payment_instruction_count, 1)
  assert_eq(report.summary.transaction_count, 2)
}

///|
test "invalid pain.001 reports required-field and duplicate issues" {
  let report = @moonpay_flow.validate_pain001(invalid_pain001_xml())
  assert_false(report.is_valid())
  assert_true(report.diagnostics.length() >= 6)
}

///|
test "validation report supports json and markdown" {
  let report = @moonpay_flow.validate_pain001(valid_pain001_xml())
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
  let report = @moonpay_flow.validate_pain001(invalid_format_pain001_xml())
  assert_false(report.is_valid())
  assert_true(report.diagnostics.length() >= 5)
}

///|
fn invalid_control_sum_pain001_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr>
  #|      <MsgId>MSG-CTRL</MsgId>
  #|      <CreDtTm>2026-10-08T12:00:00Z</CreDtTm>
  #|      <NbOfTxs>2</NbOfTxs>
  #|      <CtrlSum>999.99</CtrlSum>
  #|    </GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-CTRL</PmtInfId>
  #|      <ReqdExctnDt>2026-10-10</ReqdExctnDt>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-CTRL-1</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">100.00</InstdAmt></Amt>
  #|      </CdtTrfTxInf>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-CTRL-2</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">250.00</InstdAmt></Amt>
  #|      </CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  xml
}

///|
test "control sum mismatch is reported" {
  let report = @moonpay_flow.validate_pain001(invalid_control_sum_pain001_xml())
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("CONTROL_SUM_MISMATCH"))
}


///|
fn invalid_identity_pain001_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr>
  #|      <MsgId>MSG-IDENTITY-IDENTITY-IDENTITY-12345</MsgId>
  #|      <CreDtTm>2026-10-08T12:00:00Z</CreDtTm>
  #|      <NbOfTxs>2</NbOfTxs>
  #|      <CtrlSum>20.00</CtrlSum>
  #|    </GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-DUP</PmtInfId>
  #|      <PmtMtd>XXX</PmtMtd>
  #|      <ChrgBr>NONE</ChrgBr>
  #|      <ReqdExctnDt>2026-10-10</ReqdExctnDt>
  #|      <DbtrAgt><FinInstnId><BIC>BAD</BIC></FinInstnId></DbtrAgt>
  #|      <DbtrAcct><Id><IBAN>DE00370400440532013000</IBAN></Id></DbtrAcct>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-ID-1</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt>
  #|        <CdtrAgt><FinInstnId><BIC>bad</BIC></FinInstnId></CdtrAgt>
  #|        <CdtrAcct><Id><IBAN>DE00370400440532013000</IBAN></Id></CdtrAcct>
  #|      </CdtTrfTxInf>
  #|    </PmtInf>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-DUP</PmtInfId>
  #|      <ReqdExctnDt>2026-10-10</ReqdExctnDt>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-ID-2</EndToEndId></PmtId>
  #|        <Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt>
  #|      </CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  xml
}

///|
test "identity, enum, iban and bic checks are reported" {
  let report = @moonpay_flow.validate_pain001(invalid_identity_pain001_xml())
  assert_false(report.is_valid())
  let json = report.to_json()
  assert_true(json.contains("PAYMENT_INSTRUCTION_ID_DUPLICATE"))
  assert_true(json.contains("PAYMENT_METHOD_INVALID"))
  assert_true(json.contains("CHARGE_BEARER_INVALID"))
  assert_true(json.contains("DEBTOR_IBAN_INVALID"))
  assert_true(json.contains("DEBTOR_BIC_INVALID"))
  assert_true(json.contains("CREDITOR_IBAN_INVALID"))
  assert_true(json.contains("CREDITOR_BIC_INVALID"))
}
