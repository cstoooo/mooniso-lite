///|
test "pain.001 reconciles against pain.002" {
  let pain =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr><MsgId>MSG-001</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm><NbOfTxs>2</NbOfTxs><CtrlSum>350.00</CtrlSum></GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-001</PmtInfId>
  #|      <ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>TX-001</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">100.00</InstdAmt></Amt></CdtTrfTxInf>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>TX-002</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">250.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let status =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt>
  #|    <GrpHdr><MsgId>STS-001</MsgId><CreDtTm>2026-10-16T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-001</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-002</OrgnlEndToEndId><TxSts>RJCT</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @mooniso_lite.reconcile_pain001_status(pain, status)
  assert_eq(report.matched, 2)
  assert_eq(report.missing_status.length(), 0)
  assert_eq(report.missing_payment.length(), 0)
  assert_true(report.to_json().contains("\"matched\": 2"))
}

///|
test "reconciliation reports missing status entries" {
  let pain =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr><MsgId>MSG-X</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm><NbOfTxs>1</NbOfTxs><CtrlSum>10.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>PMT-X</PmtInfId><ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>TX-X</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let status =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>STS-X</MsgId><CreDtTm>2026-10-16T09:00:00Z</CreDtTm></GrpHdr></CstmrPmtStsRpt>
  #|</Document>
  let report = @mooniso_lite.reconcile_pain001_status(pain, status)
  assert_eq(report.matched, 0)
  assert_eq(report.missing_status.length(), 1)
}
