///|
fn pain001_without_payment_instruction() -> String {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr><MsgId>MSG-EMPTY</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  xml
}

///|
test "validation reports missing payment instruction" {
  let report = @mooniso_lite.validate_pain001(pain001_without_payment_instruction())
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("PAYMENT_INSTRUCTION_MISSING"))
}

///|
test "validation reports duplicate payment instruction id" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr><MsgId>MSG-DUP-PMT</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm><NbOfTxs>2</NbOfTxs><CtrlSum>20.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>DUP</PmtInfId><ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>T1</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|    <PmtInf><PmtInfId>DUP</PmtInfId><ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>T2</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let report = @mooniso_lite.validate_pain001(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("PAYMENT_INSTRUCTION_ID_DUPLICATE"))
}

///|
test "validation reports malformed dates amount and currency" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr><MsgId>MSG-FMT</MsgId><CreDtTm>08-10-2026 12:00</CreDtTm><NbOfTxs>1</NbOfTxs><CtrlSum>1.23</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>P1</PmtInfId><ReqdExctnDt>10/10/2026</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>T1</EndToEndId></PmtId><Amt><InstdAmt Ccy="eur">1.234</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let json = @mooniso_lite.validate_pain001(xml).to_json()
  assert_true(json.contains("CREATION_TIME_INVALID"))
  assert_true(json.contains("EXECUTION_DATE_INVALID"))
  assert_true(json.contains("INSTRUCTION_AMOUNT_INVALID"))
  assert_true(json.contains("INSTRUCTION_CURRENCY_INVALID"))
}

///|
test "validation reports long end-to-end id and transaction count mismatch" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr><MsgId>MSG-LONG</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm><NbOfTxs>2</NbOfTxs><CtrlSum>10.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>P1</PmtInfId><ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let json = @mooniso_lite.validate_pain001(xml).to_json()
  assert_true(json.contains("END_TO_END_ID_TOO_LONG"))
  assert_true(json.contains("TRANSACTION_COUNT_MISMATCH"))
}


///|
test "validation rejects zero instructed amount" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn><GrpHdr><MsgId>MSG-ZERO</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm><NbOfTxs>1</NbOfTxs><CtrlSum>0.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>P-ZERO</PmtInfId><ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>T-ZERO</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">0.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let report = @mooniso_lite.validate_pain001(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("INSTRUCTION_AMOUNT_NOT_POSITIVE"))
}
