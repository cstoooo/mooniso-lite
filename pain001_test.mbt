///|
fn sample_xml() -> String {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">
  #|  <CstmrCdtTrfInitn>
  #|    <GrpHdr>
  #|      <MsgId>MSG-001</MsgId>
  #|      <CreDtTm>2026-10-08T12:00:00Z</CreDtTm>
  #|    </GrpHdr>
  #|    <PmtInf>
  #|      <PmtInfId>PMT-001</PmtInfId>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-001</EndToEndId></PmtId>
  #|      </CdtTrfTxInf>
  #|      <CdtTrfTxInf>
  #|        <PmtId><EndToEndId>TX-002</EndToEndId></PmtId>
  #|      </CdtTrfTxInf>
  #|    </PmtInf>
  #|  </CstmrCdtTrfInitn>
  #|</Document>
  xml
}

///|
test "summarize pain.001 fields" {
  let summary = @mooniso_lite.summarize_pain001(sample_xml())
  match summary.message_id {
    Some(value) => assert_eq(value, "MSG-001")
    None => fail("missing message id")
  }
  match summary.creation_datetime {
    Some(value) => assert_eq(value, "2026-10-08T12:00:00Z")
    None => fail("missing creation datetime")
  }
  assert_eq(summary.payment_instruction_count, 1)
  assert_eq(summary.transaction_count, 2)
}
