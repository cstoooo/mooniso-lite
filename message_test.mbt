///|
fn pain002_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt>
  #|    <GrpHdr><MsgId>STS-001</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <OrgnlGrpInfAndSts><OrgnlMsgId>MSG-001</OrgnlMsgId></OrgnlGrpInfAndSts>
  #|    <OrgnlPmtInfAndSts>
  #|      <OrgnlPmtInfId>PMT-001</OrgnlPmtInfId>
  #|      <TxInfAndSts><OrgnlEndToEndId>TX-001</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|      <TxInfAndSts><OrgnlEndToEndId>TX-002</OrgnlEndToEndId><TxSts>RJCT</TxSts></TxInfAndSts>
  #|    </OrgnlPmtInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  xml
}

///|
fn pacs008_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
  #|  <FIToFICstmrCdtTrf>
  #|    <GrpHdr><MsgId>PACS-001</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <CdtTrfTxInf><PmtId><EndToEndId>TX-001</EndToEndId></PmtId><IntrBkSttlmAmt Ccy="EUR">100.00</IntrBkSttlmAmt></CdtTrfTxInf>
  #|    <CdtTrfTxInf><PmtId><EndToEndId>TX-002</EndToEndId></PmtId><IntrBkSttlmAmt Ccy="EUR">250.00</IntrBkSttlmAmt></CdtTrfTxInf>
  #|  </FIToFICstmrCdtTrf>
  #|</Document>
  xml
}

///|
fn pacs002_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.002.001.10">
  #|  <FIToFIPmtStsRpt>
  #|    <GrpHdr><MsgId>PST-001</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <OrgnlGrpInf><OrgnlMsgId>PACS-001</OrgnlMsgId></OrgnlGrpInf>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-001</OrgnlEndToEndId><TxSts>ACSP</TxSts></TxInfAndSts>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-002</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|  </FIToFIPmtStsRpt>
  #|</Document>
  xml
}

///|
fn camt053_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  #|  <BkToCstmrStmt>
  #|    <GrpHdr><MsgId>CAMT-001</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <Stmt>
  #|      <Id>STMT-001</Id>
  #|      <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">100.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-001</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|      <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">250.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-002</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|    </Stmt>
  #|  </BkToCstmrStmt>
  #|</Document>
  xml
}

///|
test "message detection covers supported ISO messages" {
  assert_true(@moonpay_flow.detect_message_kind(pain002_xml()) is @moonpay_flow.MessageKind::Pain002)
  assert_true(@moonpay_flow.detect_message_kind(pacs008_xml()) is @moonpay_flow.MessageKind::Pacs008)
  assert_true(@moonpay_flow.detect_message_kind(pacs002_xml()) is @moonpay_flow.MessageKind::Pacs002)
  assert_true(@moonpay_flow.detect_message_kind(camt053_xml()) is @moonpay_flow.MessageKind::Camt053)
}

///|
test "valid status and statement messages pass" {
  assert_true(@moonpay_flow.validate_message(pain002_xml()).is_valid())
  assert_true(@moonpay_flow.validate_message(pacs002_xml()).is_valid())
  assert_true(@moonpay_flow.validate_message(pacs008_xml()).is_valid())
  assert_true(@moonpay_flow.validate_message(camt053_xml()).is_valid())
}

///|
test "invalid status code is reported" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt>
  #|    <GrpHdr><MsgId>STS-BAD</MsgId><CreDtTm>2026-10-16T08:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TX-BAD</OrgnlEndToEndId><TxSts>UNKNOWN</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @moonpay_flow.validate_message(xml)
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("STATUS_CODE_INVALID"))
}
