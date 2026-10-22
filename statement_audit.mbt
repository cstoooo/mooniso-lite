///|
/// Balance result for one camt.053 statement.
pub(all) enum StatementBalanceStatus {
  Balanced
  BalanceMismatch
  BalanceIncomplete
}

///|
pub fn StatementBalanceStatus::name(self : StatementBalanceStatus) -> String {
  match self {
    Balanced => "BALANCED"
    BalanceMismatch => "MISMATCH"
    BalanceIncomplete => "INCOMPLETE"
  }
}

///|
/// One opening, closing, interim or previously closed balance record.
pub struct StatementBalance {
  code : String
  amount : Decimal
  currency : String
  credit_debit : String
  signed_amount : Decimal
}

///|
/// Exact duplicate candidates grouped by account, transaction ID, amount,
/// currency, direction and reversal flag.
pub struct DuplicateStatementEntry {
  end_to_end_id : String
  amount : Decimal
  currency : String
  account_iban : String?
  credit_debit : String
  reversal : Bool
  occurrences : Int
}

///|
/// Independent audit result for one camt.053 bank statement.
pub struct StatementAuditReport {
  account_iban : String?
  account_count : Int
  entry_count : Int
  total_credits : Decimal
  total_debits : Decimal
  net_movement : Decimal
  opening_balance : StatementBalance?
  closing_balance : StatementBalance?
  expected_closing : Decimal?
  closing_difference : Decimal?
  balance_status : StatementBalanceStatus
  duplicate_entries : Array[DuplicateStatementEntry]
  diagnostics : Array[Diagnostic]
}

///|
fn balance_code_supported(code : String) -> Bool {
  code == "OPBD" || code == "PRCD" || code == "CLBD" || code == "ITBD"
}

///|
fn signed_balance_amount(amount : Decimal, direction : String) -> Decimal {
  if direction == "DBIT" {
    Decimal::zero().subtract(amount)
  } else {
    amount
  }
}

///|
fn parse_statement_balances(
  xml_text : String,
  diagnostics : Array[Diagnostic],
) -> Array[StatementBalance] raise XmlParseError {
  let reader = XmlReader::from_string(xml_text)
  let path : Array[String] = []
  let balances : Array[StatementBalance] = []
  let mut in_balance = false
  let mut code : String? = None
  let mut amount_text : String? = None
  let mut currency : String? = None
  let mut direction : String? = None
  for ;; {
    match reader.read_event().kind {
      Start(element) => {
        path.push(element.name)
        if path_equals(path, ["Document", "BkToCstmrStmt", "Stmt", "Bal"]) {
          in_balance = true
          code = None
          amount_text = None
          currency = None
          direction = None
        }
        if path_equals(path, ["Document", "BkToCstmrStmt", "Stmt", "Bal", "Amt"]) {
          currency = element.get("Ccy")
        }
      }
      Empty(element) => {
        path.push(element.name)
        if path_equals(path, ["Document", "BkToCstmrStmt", "Stmt", "Bal", "Amt"]) {
          currency = element.get("Ccy")
        }
        let _ = path.remove(path.length() - 1)
      }
      Text(content) =>
        if path_equals(path, [
            "Document", "BkToCstmrStmt", "Stmt", "Bal", "Tp", "CdOrPrtry", "Cd",
          ]) {
          code = Some(content)
        } else if path_equals(path, [
            "Document", "BkToCstmrStmt", "Stmt", "Bal", "Amt",
          ]) {
          amount_text = Some(content)
        } else if path_equals(path, [
            "Document", "BkToCstmrStmt", "Stmt", "Bal", "CdtDbtInd",
          ]) {
          direction = Some(content)
        }
      End(name) => {
        if name == "Bal" && in_balance {
          match code {
            Some(balance_code) =>
              if balance_code_supported(balance_code) {
                match amount_text {
                  Some(raw_amount) =>
                    match Decimal::parse(raw_amount) {
                      Some(amount) => {
                        match currency {
                          Some(ccy) =>
                            if !is_currency(ccy) {
                              push_diagnostic(
                                diagnostics, "BALANCE_CURRENCY_INVALID", "Stmt/Bal/Amt/@Ccy",
                                "Balance currency must be a three-letter uppercase code.",
                              )
                            }
                          None =>
                            push_diagnostic(
                              diagnostics, "BALANCE_CURRENCY_MISSING", "Stmt/Bal/Amt/@Ccy",
                              "Balance currency is required.",
                            )
                        }
                        match direction {
                          Some(direction_value) =>
                            if direction_value != "CRDT" &&
                              direction_value != "DBIT" {
                              push_diagnostic(
                                diagnostics, "BALANCE_DIRECTION_INVALID", "Stmt/Bal/CdtDbtInd",
                                "Balance credit/debit indicator must be CRDT or DBIT.",
                              )
                            }
                          None =>
                            push_diagnostic(
                              diagnostics, "BALANCE_DIRECTION_MISSING", "Stmt/Bal/CdtDbtInd",
                              "Balance credit/debit indicator is required.",
                            )
                        }
                        match (currency, direction) {
                          (Some(ccy), Some(direction_value)) =>
                            if is_currency(ccy) &&
                              (
                                direction_value == "CRDT" ||
                                direction_value == "DBIT"
                              ) {
                              balances.push({
                                code: balance_code,
                                amount,
                                currency: ccy,
                                credit_debit: direction_value,
                                signed_amount: signed_balance_amount(
                                  amount, direction_value,
                                ),
                              })
                            }
                          _ => ()
                        }
                      }
                      None =>
                        push_diagnostic(
                          diagnostics, "BALANCE_AMOUNT_INVALID", "Stmt/Bal/Amt",
                          "Balance amount must be a decimal with up to two decimal places.",
                        )
                    }
                  None =>
                    push_diagnostic(
                      diagnostics, "BALANCE_AMOUNT_MISSING", "Stmt/Bal/Amt", "Balance amount value is required.",
                    )
                }
              }
            None =>
              push_diagnostic(
                diagnostics, "BALANCE_TYPE_MISSING", "Stmt/Bal/Tp/CdOrPrtry/Cd",
                "Balance type code is required.",
              )
          }
          in_balance = false
        }
        if path.length() > 0 {
          let _ = path.remove(path.length() - 1)
        }
      }
      Eof => break
    }
  }
  balances
}

///|
fn find_balance(
  balances : Array[StatementBalance],
  preferred : String,
  fallback : String,
) -> StatementBalance? {
  for balance in balances {
    if balance.code == preferred {
      return Some(balance)
    }
  }
  for balance in balances {
    if balance.code == fallback {
      return Some(balance)
    }
  }
  None
}

///|
fn account_text(record : StatementRecord) -> String {
  match record.account_iban {
    Some(value) => value
    None => ""
  }
}

///|
fn duplicate_key(record : StatementRecord) -> String {
  record.end_to_end_id +
  "|" +
  account_text(record) +
  "|" +
  record.amount.to_string() +
  "|" +
  record.currency +
  "|" +
  record.credit_debit +
  "|" +
  (if record.reversal { "1" } else { "0" })
}

///|
fn collect_duplicate_entries(
  records : Array[StatementRecord],
  diagnostics : Array[Diagnostic],
) -> Array[DuplicateStatementEntry] {
  let counts : Map[String, Int] = Map([])
  for record in records {
    let key = duplicate_key(record)
    let count = match counts.get(key) {
      Some(value) => value
      None => 0
    }
    counts.set(key, count + 1)
  }
  let emitted : Map[String, Bool] = Map([])
  let duplicates : Array[DuplicateStatementEntry] = []
  for record in records {
    let key = duplicate_key(record)
    let count = counts.get(key).unwrap()
    if count > 1 && !emitted.contains(key) {
      emitted.set(key, true)
      duplicates.push({
        end_to_end_id: record.end_to_end_id,
        amount: record.amount,
        currency: record.currency,
        account_iban: record.account_iban,
        credit_debit: record.credit_debit,
        reversal: record.reversal,
        occurrences: count,
      })
      push_diagnostic(
        diagnostics,
        "STATEMENT_ENTRY_DUPLICATE",
        "Ntry/NtryDtls/TxDtls/Refs/EndToEndId",
        "Exact statement entry is repeated " +
        count.to_string() +
        " times for end-to-end ID " +
        record.end_to_end_id +
        ".",
      )
    }
  }
  duplicates
}

///|
/// Audit statement balances, movement totals, account scope and exact duplicates.
pub fn statement_audit(
  xml_text : String,
) -> StatementAuditReport raise XmlParseError {
  let fields = flatten_xml(xml_text)
  let records = statement_records(xml_text)
  let diagnostics : Array[Diagnostic] = []
  let balances = parse_statement_balances(xml_text, diagnostics)
  let account_ids : Map[String, Bool] = Map([])
  let account_order : Array[String] = []
  for field in fields {
    if field.path.has_suffix("/Stmt/Acct/Id/IBAN") {
      match field.text {
        Some(value) =>
          if value != "" && !account_ids.contains(value) {
            account_ids.set(value, true)
            account_order.push(value)
          }
        None => ()
      }
    }
  }
  let account_count = account_order.length()
  let account_iban = if account_count > 0 {
    Some(account_order[0])
  } else {
    None
  }
  if account_count == 0 {
    push_diagnostic(
      diagnostics, "STATEMENT_ACCOUNT_MISSING", "Stmt/Acct/Id/IBAN", "Statement account IBAN is required for balance audit.",
    )
  } else if account_count > 1 {
    push_diagnostic(
      diagnostics, "MULTI_ACCOUNT_STATEMENT_UNSUPPORTED", "Stmt/Acct/Id/IBAN", "This version audits one statement account per file; multiple account IBANs were found.",
    )
  }
  let xml_entry_count = elements_by_suffix(fields, "/Ntry").length()
  if records.length() != xml_entry_count {
    push_diagnostic(
      diagnostics, "STATEMENT_ENTRY_INCOMPLETE", "Ntry", "Each statement entry must contain an end-to-end ID, amount, currency and valid direction for audit.",
    )
  }
  let currency_ids : Map[String, Bool] = Map([])
  let mut total_credits = Decimal::zero()
  let mut total_debits = Decimal::zero()
  for record in records {
    currency_ids.set(record.currency, true)
    if record.credit_debit == "CRDT" {
      total_credits = total_credits.add(record.amount)
    } else if record.credit_debit == "DBIT" {
      total_debits = total_debits.add(record.amount)
    } else {
      push_diagnostic(
        diagnostics, "ENTRY_CREDIT_DEBIT_INVALID", "Ntry/CdtDbtInd", "Credit/debit indicator must be CRDT or DBIT.",
      )
    }
  }
  let net_movement = total_credits.subtract(total_debits)
  let mut entry_currency : String? = None
  for record in records {
    if entry_currency is None {
      entry_currency = Some(record.currency)
    }
  }
  if currency_ids.length() > 1 {
    push_diagnostic(
      diagnostics, "STATEMENT_CURRENCY_MIXED", "Ntry/Amt/@Ccy", "Statement entries use more than one currency; balance arithmetic requires one currency.",
    )
  }
  let opening_balance = find_balance(balances, "OPBD", "PRCD")
  let closing_balance = find_balance(balances, "CLBD", "ITBD")
  match opening_balance {
    Some(_) => ()
    None =>
      push_diagnostic(
        diagnostics, "OPENING_BALANCE_MISSING", "Stmt/Bal/Tp/CdOrPrtry/Cd", "Opening balance OPBD or previously closed balance PRCD is required.",
      )
  }
  match closing_balance {
    Some(_) => ()
    None =>
      push_diagnostic(
        diagnostics, "CLOSING_BALANCE_MISSING", "Stmt/Bal/Tp/CdOrPrtry/Cd", "Closing balance CLBD or interim booked balance ITBD is required.",
      )
  }
  for balance in balances {
    match entry_currency {
      Some(currency) =>
        if balance.currency != currency {
          push_diagnostic(
            diagnostics,
            "BALANCE_CURRENCY_MISMATCH",
            "Stmt/Bal/Amt/@Ccy",
            "Balance currency " +
            balance.currency +
            " does not match statement entry currency " +
            currency +
            ".",
          )
        }
      None => ()
    }
  }
  let expected_closing : Decimal? = match opening_balance {
    Some(opening) => Some(opening.signed_amount.add(net_movement))
    None => None
  }
  let closing_difference : Decimal? = match (opening_balance, closing_balance) {
    (Some(opening), Some(closing)) =>
      Some(
        closing.signed_amount.subtract(opening.signed_amount.add(net_movement)),
      )
    _ => None
  }
  let balance_status = match
    (opening_balance, closing_balance, closing_difference) {
    (Some(_), Some(_), Some(difference)) =>
      if difference.compare(Decimal::zero()) == 0 {
        Balanced
      } else {
        push_diagnostic(
          diagnostics,
          "BALANCE_MISMATCH",
          "Stmt/Bal",
          "Closing balance does not equal opening balance plus credits minus debits; difference is " +
          difference.to_string() +
          ".",
        )
        BalanceMismatch
      }
    _ => BalanceIncomplete
  }
  let duplicate_entries = collect_duplicate_entries(records, diagnostics)
  {
    account_iban,
    account_count,
    entry_count: records.length(),
    total_credits,
    total_debits,
    net_movement,
    opening_balance,
    closing_balance,
    expected_closing,
    closing_difference,
    balance_status,
    duplicate_entries,
    diagnostics,
  }
}

///|
pub fn StatementAuditReport::is_valid(self : StatementAuditReport) -> Bool {
  self.diagnostics.length() == 0
}

///|
fn balance_to_json(balance : StatementBalance?) -> Json {
  match balance {
    Some(value) => {
      let item = Map([])
      item.set("code", Json::string(value.code))
      item.set("amount", Json::string(value.amount.to_string()))
      item.set("currency", Json::string(value.currency))
      item.set("creditDebit", Json::string(value.credit_debit))
      item.set("signedAmount", Json::string(value.signed_amount.to_string()))
      Json::object(item)
    }
    None => Json::null()
  }
}

///|
fn optional_decimal_to_json(value : Decimal?) -> Json {
  match value {
    Some(decimal) => Json::string(decimal.to_string())
    None => Json::null()
  }
}

///|
pub fn StatementAuditReport::to_text(self : StatementAuditReport) -> String {
  let output = StringBuilder()
  output.write_string("Bank statement audit\nAccount: ")
  output.write_string(
    match self.account_iban {
      Some(value) => value
      None => "(missing)"
    },
  )
  output.write_string("\nAccounts: ")
  output.write_string(self.account_count.to_string())
  output.write_string("\nEntries: ")
  output.write_string(self.entry_count.to_string())
  output.write_string("\nCredits: ")
  output.write_string(self.total_credits.to_string())
  output.write_string("\nDebits: ")
  output.write_string(self.total_debits.to_string())
  output.write_string("\nNet movement: ")
  output.write_string(self.net_movement.to_string())
  output.write_string("\nOpening balance: ")
  output.write_string(
    match self.opening_balance {
      Some(value) =>
        value.signed_amount.to_string() +
        " " +
        value.currency +
        " (" +
        value.code +
        ")"
      None => "(missing)"
    },
  )
  output.write_string("\nClosing balance: ")
  output.write_string(
    match self.closing_balance {
      Some(value) =>
        value.signed_amount.to_string() +
        " " +
        value.currency +
        " (" +
        value.code +
        ")"
      None => "(missing)"
    },
  )
  output.write_string("\nExpected closing: ")
  output.write_string(
    match self.expected_closing {
      Some(value) => value.to_string()
      None => "(not calculable)"
    },
  )
  output.write_string("\nClosing difference: ")
  output.write_string(
    match self.closing_difference {
      Some(value) => value.to_string()
      None => "(not calculable)"
    },
  )
  output.write_string("\nBalance status: ")
  output.write_string(self.balance_status.name())
  output.write_string("\nDuplicate groups: ")
  output.write_string(self.duplicate_entries.length().to_string())
  for duplicate in self.duplicate_entries {
    output.write_string("\n- ")
    output.write_string(duplicate.end_to_end_id)
    output.write_string(" | ")
    output.write_string(duplicate.amount.to_string())
    output.write_string(" ")
    output.write_string(duplicate.currency)
    output.write_string(" | ")
    output.write_string(duplicate.credit_debit)
    output.write_string(" | occurrences=")
    output.write_string(duplicate.occurrences.to_string())
  }
  output.write_string("\nResult: ")
  if self.is_valid() {
    output.write_string("VALID")
  } else {
    output.write_string("ISSUES FOUND (")
    output.write_string(self.diagnostics.length().to_string())
    output.write_string(")")
    for diagnostic in self.diagnostics {
      output.write_string("\n- [")
      output.write_string(diagnostic.code)
      output.write_string("] ")
      output.write_string(diagnostic.path)
      output.write_string(": ")
      output.write_string(diagnostic.message)
    }
  }
  output.to_string()
}

///|
pub fn StatementAuditReport::to_json(self : StatementAuditReport) -> String {
  let duplicates : Array[Json] = []
  for duplicate in self.duplicate_entries {
    let account : Json = match duplicate.account_iban {
      Some(value) => Json::string(value)
      None => Json::null()
    }
    duplicates.push({
      "endToEndId": duplicate.end_to_end_id,
      "amount": duplicate.amount.to_string(),
      "currency": duplicate.currency,
      "accountIban": account,
      "creditDebit": duplicate.credit_debit,
      "reversal": duplicate.reversal,
      "occurrences": duplicate.occurrences,
    })
  }
  let diagnostics : Array[Json] = []
  for diagnostic in self.diagnostics {
    diagnostics.push({
      "code": diagnostic.code,
      "path": diagnostic.path,
      "message": diagnostic.message,
    })
  }
  let account_iban : Json = match self.account_iban {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let root = Map([])
  root.set("valid", Json::boolean(self.is_valid()))
  root.set("accountIban", account_iban)
  root.set("accountCount", Json::number(self.account_count.to_double()))
  root.set("entryCount", Json::number(self.entry_count.to_double()))
  root.set("totalCredits", Json::string(self.total_credits.to_string()))
  root.set("totalDebits", Json::string(self.total_debits.to_string()))
  root.set("netMovement", Json::string(self.net_movement.to_string()))
  root.set("openingBalance", balance_to_json(self.opening_balance))
  root.set("closingBalance", balance_to_json(self.closing_balance))
  root.set("expectedClosing", optional_decimal_to_json(self.expected_closing))
  root.set(
    "closingDifference",
    optional_decimal_to_json(self.closing_difference),
  )
  root.set("balanceStatus", Json::string(self.balance_status.name()))
  root.set("duplicateGroups", Json::array(duplicates))
  root.set("diagnostics", Json::array(diagnostics))
  Json::object(root).stringify(indent=2)
}

///|
pub fn StatementAuditReport::to_markdown(self : StatementAuditReport) -> String {
  let output = StringBuilder()
  output.write_string("# Bank statement audit\n\n")
  output.write_string("| Field | Value |\n|---|---|\n")
  output.write_string("| Account | `")
  output.write_string(
    match self.account_iban {
      Some(value) => value
      None => "(missing)"
    },
  )
  output.write_string("` |\n")
  output.write_string("| Entries | ")
  output.write_string(self.entry_count.to_string())
  output.write_string(" |\n| Credits | ")
  output.write_string(self.total_credits.to_string())
  output.write_string(" |\n| Debits | ")
  output.write_string(self.total_debits.to_string())
  output.write_string(" |\n| Net movement | ")
  output.write_string(self.net_movement.to_string())
  output.write_string(" |\n| Balance status | `")
  output.write_string(self.balance_status.name())
  output.write_string("` |\n| Duplicate groups | ")
  output.write_string(self.duplicate_entries.length().to_string())
  output.write_string(" |\n\n## Diagnostics\n\n")
  if self.is_valid() {
    output.write_string("No issues found.\n")
  } else {
    output.write_string("| Code | Path | Message |\n|---|---|---|\n")
    for diagnostic in self.diagnostics {
      output.write_string("| `")
      output.write_string(diagnostic.code)
      output.write_string("` | `")
      output.write_string(diagnostic.path)
      output.write_string("` | ")
      output.write_string(diagnostic.message)
      output.write_string(" |\n")
    }
  }
  output.to_string()
}
