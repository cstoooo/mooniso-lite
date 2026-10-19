///|
test "message detection reports unknown type" {
  let report = @mooniso_lite.validate_message("<Document><Unknown/></Document>")
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("UNKNOWN_MESSAGE_TYPE"))
}

///|
test "status report reports incomplete entry" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>STS-INC</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-INC</OrgnlEndToEndId></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @mooniso_lite.validate_message(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("STATUS_ENTRY_INCOMPLETE"))
}

///|
test "status report reports duplicate original id" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>STS-DUP</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-DUP</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-DUP</OrgnlEndToEndId><TxSts>RJCT</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @mooniso_lite.validate_message(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("STATUS_ID_DUPLICATE"))
}

///|
test "pacs008 reports invalid amount and missing currency" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
  #|  <FIToFICstmrCdtTrf><GrpHdr><MsgId>PACS-BAD</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <CdtTrfTxInf><PmtId><EndToEndId>TX-BAD</EndToEndId></PmtId><IntrBkSttlmAmt>bad</IntrBkSttlmAmt></CdtTrfTxInf>
  #|  </FIToFICstmrCdtTrf>
  #|</Document>
  let report = @mooniso_lite.validate_message(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("SETTLEMENT_AMOUNT_INVALID"))
  assert_true(report.to_json().contains("SETTLEMENT_CURRENCY_MISSING"))
}

///|
test "camt053 reports invalid amount and missing currency" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  #|  <BkToCstmrStmt><GrpHdr><MsgId>CAMT-BAD</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <Stmt><Id>STMT-BAD</Id><Ntry><Amt>bad</Amt></Ntry></Stmt>
  #|  </BkToCstmrStmt>
  #|</Document>
  let report = @mooniso_lite.validate_message(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("STATEMENT_AMOUNT_INVALID"))
  assert_true(report.to_json().contains("STATEMENT_CURRENCY_MISSING"))
}


///|
test "pacs008 rejects zero settlement amount" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
  #|  <FIToFICstmrCdtTrf><GrpHdr><MsgId>PACS-ZERO</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <CdtTrfTxInf><PmtId><EndToEndId>TX-ZERO</EndToEndId></PmtId><IntrBkSttlmAmt Ccy="EUR">0.00</IntrBkSttlmAmt></CdtTrfTxInf>
  #|  </FIToFICstmrCdtTrf>
  #|</Document>
  let report = @mooniso_lite.validate_message(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("SETTLEMENT_AMOUNT_NOT_POSITIVE"))
}

///|
test "camt053 validates credit debit indicator" {
  let xml =
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  #|  <BkToCstmrStmt><GrpHdr><MsgId>CAMT-IND</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <Stmt><Id>STMT-IND</Id><Ntry><CdtDbtInd>BAD</CdtDbtInd><Amt Ccy="EUR">10.00</Amt></Ntry></Stmt>
  #|  </BkToCstmrStmt>
  #|</Document>
  let report = @mooniso_lite.validate_message(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("ENTRY_CREDIT_DEBIT_INVALID"))
}
