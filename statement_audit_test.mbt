///|
fn audit_statement_xml(
  opening_amount : String,
  opening_direction : String,
  entries : String,
  closing_amount : String,
  closing_direction : String,
) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:camt.053.001.08\">\n" +
  "  <BkToCstmrStmt><GrpHdr><MsgId>AUDIT-1</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>\n" +
  "    <Stmt><Id>STMT-AUDIT-1</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>\n" +
  "      <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy=\"EUR\">" +
  opening_amount +
  "</Amt><CdtDbtInd>" +
  opening_direction +
  "</CdtDbtInd></Bal>\n" +
  entries +
  "      <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy=\"EUR\">" +
  closing_amount +
  "</Amt><CdtDbtInd>" +
  closing_direction +
  "</CdtDbtInd></Bal>\n" +
  "    </Stmt></BkToCstmrStmt></Document>"
}

///|
fn audit_entry(
  id : String,
  direction : String,
  amount : String,
  currency : String,
) -> String {
  "      <Ntry><CdtDbtInd>" +
  direction +
  "</CdtDbtInd><Amt Ccy=\"" +
  currency +
  "\">" +
  amount +
  "</Amt><NtryDtls><TxDtls><Refs><EndToEndId>" +
  id +
  "</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>\n"
}

///|
test "statement audit reconciles balance and movement totals" {
  let xml = @fs.read_file_to_string("fixtures/balanced_camt053.xml")
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.is_valid())
  assert_eq(report.account_iban.unwrap(), "DE89370400440532013000")
  assert_eq(report.account_count, 1)
  assert_eq(report.entry_count, 2)
  assert_eq(report.total_credits.to_string(), "250.00")
  assert_eq(report.total_debits.to_string(), "100.00")
  assert_eq(report.net_movement.to_string(), "150.00")
  assert_eq(report.expected_closing.unwrap().to_string(), "1150.00")
  assert_eq(report.closing_difference.unwrap().to_string(), "0.00")
  assert_eq(report.balance_status.name(), "BALANCED")
}

///|
test "statement audit reports closing balance mismatch" {
  let xml = @fs.read_file_to_string("fixtures/balance_mismatch_camt053.xml")
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.balance_status.name(), "MISMATCH")
  assert_eq(report.expected_closing.unwrap().to_string(), "1150.00")
  assert_eq(report.closing_difference.unwrap().to_string(), "50.00")
  assert_false(report.is_valid())
  assert_true(report.to_json().contains("BALANCE_MISMATCH"))
}

///|
test "statement audit reports incomplete balance evidence" {
  let entries = audit_entry("TX-ONLY", "CRDT", "10.00", "EUR")
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
    #|  <GrpHdr><MsgId>AUDIT-NO-BAL</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>
    #|  <Stmt><Id>STMT-NO-BAL</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
    #|    <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-ONLY</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
    #|  </Stmt></BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.balance_status.name(), "INCOMPLETE")
  assert_true(report.opening_balance is None)
  assert_true(report.closing_balance is None)
  assert_true(report.to_text().contains("OPENING_BALANCE_MISSING"))
  assert_true(report.to_text().contains("CLOSING_BALANCE_MISSING"))
  assert_eq(entries, audit_entry("TX-ONLY", "CRDT", "10.00", "EUR"))
}

///|
test "statement audit accepts previously closed and interim balance codes" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
    #|  <GrpHdr><MsgId>AUDIT-FALLBACK</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>
    #|  <Stmt><Id>STMT-FALLBACK</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
    #|    <Bal><Tp><CdOrPrtry><Cd>PRCD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">100.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
    #|    <Ntry><CdtDbtInd>DBIT</CdtDbtInd><Amt Ccy="EUR">25.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-FALLBACK</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
    #|    <Bal><Tp><CdOrPrtry><Cd>ITBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">75.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
    #|  </Stmt></BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.is_valid())
  assert_eq(report.opening_balance.unwrap().code, "PRCD")
  assert_eq(report.closing_balance.unwrap().code, "ITBD")
  assert_eq(report.net_movement.to_string(), "-25.00")
  assert_eq(report.balance_status.name(), "BALANCED")
}

///|
test "statement audit reports invalid balance amount" {
  let xml = audit_statement_xml("bad", "CRDT", "", "0.00", "CRDT")
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.opening_balance is None)
  assert_true(report.to_json().contains("BALANCE_AMOUNT_INVALID"))
  assert_eq(report.balance_status.name(), "INCOMPLETE")
}

///|
test "statement audit reports invalid balance currency and direction" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
    #|  <GrpHdr><MsgId>AUDIT-INVALID</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>
    #|  <Stmt><Id>STMT-INVALID</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
    #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EURO">10.00</Amt><CdtDbtInd>SIDE</CdtDbtInd></Bal>
    #|    <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-INVALID-BAL</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
    #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">20.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
    #|  </Stmt></BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.to_json().contains("BALANCE_CURRENCY_INVALID"))
  assert_true(report.to_json().contains("BALANCE_DIRECTION_INVALID"))
  assert_eq(report.balance_status.name(), "INCOMPLETE")
}

///|
test "statement audit compares balance and entry currencies" {
  let entries = audit_entry("TX-USD", "CRDT", "10.00", "USD")
  let xml = audit_statement_xml("0.00", "CRDT", entries, "10.00", "CRDT")
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.to_json().contains("BALANCE_CURRENCY_MISMATCH"))
  assert_false(report.is_valid())
}

///|
test "statement audit detects exact duplicate entries" {
  let xml = @fs.read_file_to_string("fixtures/duplicate_camt053.xml")
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.balance_status.name(), "BALANCED")
  assert_eq(report.duplicate_entries.length(), 1)
  assert_eq(report.duplicate_entries[0].end_to_end_id, "DUP-TX-001")
  assert_eq(report.duplicate_entries[0].occurrences, 2)
  assert_true(report.to_json().contains("STATEMENT_ENTRY_DUPLICATE"))
}

///|
test "statement audit keeps near duplicate amounts separate" {
  let entries = audit_entry("TX-NEAR", "CRDT", "100.00", "EUR") +
    audit_entry("TX-NEAR", "CRDT", "101.00", "EUR")
  let xml = audit_statement_xml("0.00", "CRDT", entries, "201.00", "CRDT")
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.duplicate_entries.length(), 0)
  assert_true(report.is_valid())
}

///|
test "statement audit distinguishes duplicate reversal direction" {
  let entries = audit_entry("TX-REV", "CRDT", "100.00", "EUR") +
    "      <Ntry><RvslInd>true</RvslInd><CdtDbtInd>DBIT</CdtDbtInd><Amt Ccy=\"EUR\">100.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-REV</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>\n"
  let xml = audit_statement_xml("0.00", "CRDT", entries, "0.00", "CRDT")
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.duplicate_entries.length(), 0)
  assert_true(report.is_valid())
}

///|
test "statement audit reports multiple account scope" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
    #|  <GrpHdr><MsgId>AUDIT-MULTI</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>
    #|  <Stmt><Id>STMT-A</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct><Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">1.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-A</EndToEndId></Refs></TxDtls></NtryDtls></Ntry></Stmt>
    #|  <Stmt><Id>STMT-B</Id><Acct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></Acct><Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">1.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-B</EndToEndId></Refs></TxDtls></NtryDtls></Ntry></Stmt>
    #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.account_count, 2)
  assert_true(report.to_json().contains("MULTI_ACCOUNT_STATEMENT_UNSUPPORTED"))
}

///|
test "statement audit reports mixed entry currencies" {
  let entries = audit_entry("TX-EUR", "CRDT", "10.00", "EUR") +
    audit_entry("TX-USD", "CRDT", "10.00", "USD")
  let xml = audit_statement_xml("0.00", "CRDT", entries, "20.00", "CRDT")
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.to_json().contains("STATEMENT_CURRENCY_MIXED"))
  assert_false(report.is_valid())
}

///|
test "statement audit reports missing account and incomplete entry" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
    #|  <GrpHdr><MsgId>AUDIT-MISSING</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>
    #|  <Stmt><Id>STMT-MISSING</Id><Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">1.00</Amt></Ntry></Stmt>
    #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.to_json().contains("STATEMENT_ACCOUNT_MISSING"))
  assert_true(report.to_json().contains("STATEMENT_ENTRY_INCOMPLETE"))
}

///|
test "statement audit renders text JSON and Markdown" {
  let xml = @fs.read_file_to_string("fixtures/balanced_camt053.xml")
  let report = @moonpay_flow.statement_audit(xml)
  assert_true(report.to_text().contains("Balance status: BALANCED"))
  assert_true(report.to_json().contains("\"balanceStatus\": \"BALANCED\""))
  assert_true(report.to_markdown().contains("| Balance status | `BALANCED` |"))
}

///|
test "statement audit handles debit opening and closing balances" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>AUDIT-DBIT-BAL</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>STMT-DBIT-BAL</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
  #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">100.00</Amt><CdtDbtInd>DBIT</CdtDbtInd></Bal>
  #|    <Ntry><CdtDbtInd>DBIT</CdtDbtInd><Amt Ccy="EUR">25.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-DBIT-BAL</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">125.00</Amt><CdtDbtInd>DBIT</CdtDbtInd></Bal>
  #|  </Stmt></BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.opening_balance.unwrap().signed_amount.to_string(), "-100.00")
  assert_eq(report.closing_balance.unwrap().signed_amount.to_string(), "-125.00")
  assert_eq(report.expected_closing.unwrap().to_string(), "-125.00")
  assert_eq(report.balance_status.name(), "BALANCED")
}

///|
test "statement audit detects closing direction mismatch" {
  let entries = audit_entry("TX-DIRECTION", "CRDT", "100.00", "EUR")
  let xml = audit_statement_xml("0.00", "CRDT", entries, "100.00", "DBIT")
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.balance_status.name(), "MISMATCH")
  assert_eq(report.closing_difference.unwrap().to_string(), "-200.00")
}

///|
test "statement audit duplicate key includes account ownership" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>AUDIT-ACCOUNT-KEY</MsgId><CreDtTm>2026-10-22T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>STMT-ACCOUNT-A</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct><Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">100.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-SAME</EndToEndId></Refs></TxDtls></NtryDtls></Ntry></Stmt>
  #|  <Stmt><Id>STMT-ACCOUNT-B</Id><Acct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></Acct><Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">100.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-SAME</EndToEndId></Refs></TxDtls></NtryDtls></Ntry></Stmt>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.account_count, 2)
  assert_eq(report.duplicate_entries.length(), 0)
}

///|
test "statement audit groups identical reversal entries" {
  let reversal =
    "      <Ntry><RvslInd>true</RvslInd><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy=\"EUR\">50.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>TX-DUP-REV</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>\n"
  let entries = reversal + reversal
  let xml = audit_statement_xml("0.00", "CRDT", entries, "100.00", "CRDT")
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.duplicate_entries.length(), 1)
  assert_eq(report.duplicate_entries[0].occurrences, 2)
  assert_true(report.duplicate_entries[0].reversal)
}
