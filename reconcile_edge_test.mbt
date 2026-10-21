///|
test "reconciliation reports statuses without matching payments" {
  let pain =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn><GrpHdr><MsgId>M1</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm><NbOfTxs>1</NbOfTxs><CtrlSum>10.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>P1</PmtInfId><ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>TX-A</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let status =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>S1</MsgId><CreDtTm>2026-10-16T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-A</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-EXTRA</OrgnlEndToEndId><TxSts>RJCT</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @moonpay_flow.reconcile_pain001_status(pain, status)
  assert_eq(report.matched, 1)
  assert_eq(report.missing_payment.length(), 1)
}

///|
test "reconciliation reports mismatches in both directions" {
  let pain =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn><GrpHdr><MsgId>M2</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm><NbOfTxs>1</NbOfTxs><CtrlSum>10.00</CtrlSum></GrpHdr>
  #|    <PmtInf><PmtInfId>P2</PmtInfId><ReqdExctnDt>2026-10-16</ReqdExctnDt>
  #|      <CdtTrfTxInf><PmtId><EndToEndId>TX-ONLY-PAIN</EndToEndId></PmtId><Amt><InstdAmt Ccy="EUR">10.00</InstdAmt></Amt></CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  let status =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>S2</MsgId><CreDtTm>2026-10-16T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-ONLY-STATUS</OrgnlEndToEndId><TxSts>RJCT</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @moonpay_flow.reconcile_pain001_status(pain, status)
  assert_eq(report.matched, 0)
  assert_eq(report.missing_status.length(), 1)
  assert_eq(report.missing_payment.length(), 1)
}
