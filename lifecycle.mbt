///|
pub struct StatementRecord {
  end_to_end_id : String
  amount : Decimal
  currency : String
  account_iban : String?
  credit_debit : String
  reversal : Bool
}

///|
pub(all) enum LifecycleState {
  Settled
  SettledNotPosted
  Rejected
  Pending
  MissingStatus
  StatementMismatch
  StatementBeforeFinalStatus
  PartiallyRefunded
  FullyRefunded
  AccountUnmatched
}

///|
pub fn LifecycleState::name(self : LifecycleState) -> String {
  match self {
    Settled => "SETTLED"
    SettledNotPosted => "SETTLED_NOT_POSTED"
    Rejected => "REJECTED"
    Pending => "PENDING"
    MissingStatus => "MISSING_STATUS"
    StatementMismatch => "STATEMENT_MISMATCH"
    StatementBeforeFinalStatus => "STATEMENT_BEFORE_FINAL_STATUS"
    PartiallyRefunded => "PARTIALLY_REFUNDED"
    FullyRefunded => "FULLY_REFUNDED"
    AccountUnmatched => "ACCOUNT_UNMATCHED"
  }
}

///|
pub struct LifecycleCase {
  end_to_end_id : String
  amount : Decimal
  currency : String
  debtor_iban : String?
  creditor_iban : String?
  status : String?
  statement_role : String
  net_posted : Decimal?
  reversal_count : Int
  state : LifecycleState
  action : String
}

///|
pub struct LifecycleReport {
  cases : Array[LifecycleCase]
  orphan_statuses : Array[String]
  orphan_statements : Array[String]
}

///|
pub fn statement_records(xml_text : String) -> Array[StatementRecord] raise XmlParseError {
  let reader = XmlReader::from_string(xml_text)
  let path : Array[String] = []
  let records : Array[StatementRecord] = []
  let mut account_iban : String? = None
  let mut in_entry = false
  let mut current_id : String? = None
  let mut current_amount : String? = None
  let mut current_currency : String? = None
  let mut current_direction = ""
  let mut current_reversal = false
  for ;; {
    match reader.read_event().kind {
      Start(element) => {
        path.push(element.name)
        if path_equals(path, ["Document", "BkToCstmrStmt", "Stmt", "Ntry"]) {
          in_entry = true
          current_id = None
          current_amount = None
          current_currency = None
          current_direction = ""
          current_reversal = false
        }
        if path_equals(
          path,
          ["Document", "BkToCstmrStmt", "Stmt", "Ntry", "Amt"],
        ) {
          current_currency = element.get("Ccy")
        }
      }
      Empty(element) => {
        path.push(element.name)
        if path_equals(
          path,
          ["Document", "BkToCstmrStmt", "Stmt", "Ntry", "Amt"],
        ) {
          current_currency = element.get("Ccy")
        }
        let _ = path.remove(path.length() - 1)
      }
      Text(content) => {
        if path_equals(
          path,
          ["Document", "BkToCstmrStmt", "Stmt", "Acct", "Id", "IBAN"],
        ) {
          account_iban = Some(content)
        } else if path_equals(
          path,
          ["Document", "BkToCstmrStmt", "Stmt", "Ntry", "Amt"],
        ) {
          current_amount = Some(content)
        } else if path_equals(
          path,
          ["Document", "BkToCstmrStmt", "Stmt", "Ntry", "CdtDbtInd"],
        ) {
          current_direction = content
        } else if path_equals(
          path,
          ["Document", "BkToCstmrStmt", "Stmt", "Ntry", "RvslInd"],
        ) {
          current_reversal = content == "true" || content == "1"
        } else if path_equals(
          path,
          [
            "Document",
            "BkToCstmrStmt",
            "Stmt",
            "Ntry",
            "NtryDtls",
            "TxDtls",
            "Refs",
            "EndToEndId",
          ],
        ) {
          current_id = Some(content)
        }
      }
      End(name) => {
        if name == "Ntry" && in_entry {
          match current_id {
            Some(id) =>
              match current_amount {
                Some(amount_text) =>
                  match current_currency {
                    Some(currency) =>
                      match Decimal::parse(amount_text) {
                        Some(amount) =>
                          records.push({
                            end_to_end_id: id,
                            amount,
                            currency,
                            account_iban,
                            credit_debit: current_direction,
                            reversal: current_reversal,
                          })
                        None => ()
                      }
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
          in_entry = false
        }
        if path.length() > 0 {
          let _ = path.remove(path.length() - 1)
        }
      }
      Eof => break
    }
  }
  records
}

///|
fn action_for_state(state : LifecycleState) -> String {
  match state {
    Settled => "No action; retain the report as audit evidence."
    SettledNotPosted => "Check statement import and bank posting."
    Rejected => "Review the rejection reason and decide whether to resend."
    Pending => "Query the payment status again later."
    MissingStatus => "Request a status report from the payment provider."
    StatementMismatch => "Open an exception and verify amount, currency or posting direction."
    StatementBeforeFinalStatus => "Reconcile the statement entry with the current status."
    PartiallyRefunded => "Check the refund/reversal amount and remaining balance."
    FullyRefunded => "Do not treat this payment as completed; verify the refund or reversal."
    AccountUnmatched => "Verify that the statement account belongs to the debtor or creditor."
  }
}

///|
fn statement_role(
  statement : StatementRecord,
  payment : PaymentRecord,
) -> String {
  match statement.account_iban {
    Some(account) => {
      match payment.debtor_iban {
        Some(debtor) =>
          if account == debtor {
            return "DEBTOR"
          }
        None => ()
      }
      match payment.creditor_iban {
        Some(creditor) =>
          if account == creditor {
            return "CREDITOR"
          }
        None => ()
      }
    }
    None => ()
  }
  "UNKNOWN"
}

///|
fn selected_statements(
  statements : Array[StatementRecord],
  payment : PaymentRecord,
) -> Array[StatementRecord] {
  let has_debtor = statements.iter().any(fn(statement) {
    statement_role(statement, payment) == "DEBTOR"
  })
  let has_creditor = statements.iter().any(fn(statement) {
    statement_role(statement, payment) == "CREDITOR"
  })
  let selected_role = if has_debtor {
    "DEBTOR"
  } else if has_creditor {
    "CREDITOR"
  } else {
    "UNKNOWN"
  }
  let result : Array[StatementRecord] = []
  for statement in statements {
    if statement_role(statement, payment) == selected_role {
      result.push(statement)
    }
  }
  result
}

///|
fn classify_case(
  status : String?,
  all_statements : Array[StatementRecord],
  payment : PaymentRecord,
) -> (LifecycleState, String, Decimal?, Int) {
  let statements = selected_statements(all_statements, payment)
  if statements.length() == 0 {
    let state = match status {
      Some(value) =>
        if value == "ACSC" {
          SettledNotPosted
        } else if value == "RJCT" {
          Rejected
        } else {
          Pending
        }
      None => MissingStatus
    }
    return (state, "UNKNOWN", None, 0)
  }
  let role = statement_role(statements[0], payment)
  if role == "UNKNOWN" {
    return (AccountUnmatched, role, None, 0)
  }
  let normal_direction = if role == "DEBTOR" { "DBIT" } else { "CRDT" }
  let mut net = Decimal::zero()
  let mut reversal_count = 0
  let mut currency_mismatch = false
  for statement in statements {
    if statement.currency != payment.currency {
      currency_mismatch = true
    }
    let normal = statement.credit_debit == normal_direction && !statement.reversal
    if normal {
      net = net.add(statement.amount)
    } else {
      net = net.subtract(statement.amount)
      reversal_count += 1
    }
  }
  if currency_mismatch {
    return (StatementMismatch, role, Some(net), reversal_count)
  }
  if net.compare(Decimal::zero()) <= 0 {
    return (FullyRefunded, role, Some(net), reversal_count)
  }
  if net.compare(payment.amount) == 0 {
    let state = match status {
      Some(value) =>
        if value == "ACSC" {
          Settled
        } else if value == "RJCT" {
          Rejected
        } else {
          StatementBeforeFinalStatus
        }
      None => MissingStatus
    }
    return (state, role, Some(net), reversal_count)
  }
  if net.compare(payment.amount) < 0 {
    if reversal_count > 0 {
      return (PartiallyRefunded, role, Some(net), reversal_count)
    }
    return (StatementMismatch, role, Some(net), reversal_count)
  }
  (StatementMismatch, role, Some(net), reversal_count)
}

///|
pub fn lifecycle_report(
  pain_xml : String,
  status_xml : String,
  statement_xml : String,
) -> LifecycleReport raise XmlParseError {
  let payments = pain001_payment_records(pain_xml)
  let statuses = status_records(status_xml)
  let statements = statement_records(statement_xml)
  let status_map : Map[String, String] = Map([])
  for record in statuses {
    status_map.set(record.end_to_end_id, record.status)
  }
  let payment_ids : Map[String, Bool] = Map([])
  let cases : Array[LifecycleCase] = []
  for payment in payments {
    payment_ids.set(payment.end_to_end_id, true)
    let records : Array[StatementRecord] = []
    for statement in statements {
      if statement.end_to_end_id == payment.end_to_end_id {
        records.push(statement)
      }
    }
    let status = status_map.get(payment.end_to_end_id)
    let (state, role, net_posted, reversal_count) = classify_case(status, records, payment)
    cases.push({
      end_to_end_id: payment.end_to_end_id,
      amount: payment.amount,
      currency: payment.currency,
      debtor_iban: payment.debtor_iban,
      creditor_iban: payment.creditor_iban,
      status,
      statement_role: role,
      net_posted,
      reversal_count,
      state,
      action: action_for_state(state),
    })
  }
  let orphan_statuses : Array[String] = []
  for record in statuses {
    if !payment_ids.contains(record.end_to_end_id) {
      orphan_statuses.push(record.end_to_end_id)
    }
  }
  let orphan_statements : Array[String] = []
  for record in statements {
    if !payment_ids.contains(record.end_to_end_id) {
      orphan_statements.push(record.end_to_end_id)
    }
  }
  { cases, orphan_statuses, orphan_statements }
}

///|
pub fn LifecycleReport::to_text(self : LifecycleReport) -> String {
  let output = StringBuilder()
  output.write_string("Payment lifecycle report\n")
  for case in self.cases {
    output.write_string("\n")
    output.write_string(case.end_to_end_id)
    output.write_string(" | ")
    output.write_string(case.amount.to_string())
    output.write_string(" ")
    output.write_string(case.currency)
    output.write_string(" | status=")
    output.write_string(match case.status {
      Some(value) => value
      None => "(missing)"
    })
    output.write_string(" | account=")
    output.write_string(case.statement_role)
    output.write_string(" | net=")
    output.write_string(match case.net_posted {
      Some(value) => value.to_string()
      None => "(not posted)"
    })
    output.write_string(" | reversals=")
    output.write_string(case.reversal_count.to_string())
    output.write_string(" | state=")
    output.write_string(case.state.name())
    output.write_string("\nAction: ")
    output.write_string(case.action)
    output.write_string("\n")
  }
  if self.orphan_statuses.length() > 0 {
    output.write_string("\nStatus entries without payment:")
    for id in self.orphan_statuses {
      output.write_string("\n- ")
      output.write_string(id)
    }
  }
  if self.orphan_statements.length() > 0 {
    output.write_string("\nStatement entries without payment:")
    for id in self.orphan_statements {
      output.write_string("\n- ")
      output.write_string(id)
    }
  }
  output.to_string()
}

///|
pub fn LifecycleReport::to_json(self : LifecycleReport) -> String {
  let cases : Array[Json] = []
  for case in self.cases {
    let status : Json = match case.status {
      Some(value) => Json::string(value)
      None => Json::null()
    }
    let debtor_iban : Json = match case.debtor_iban {
      Some(value) => Json::string(value)
      None => Json::null()
    }
    let creditor_iban : Json = match case.creditor_iban {
      Some(value) => Json::string(value)
      None => Json::null()
    }
    let net_posted : Json = match case.net_posted {
      Some(value) => Json::string(value.to_string())
      None => Json::null()
    }
    cases.push({
      "endToEndId": case.end_to_end_id,
      "amount": case.amount.to_string(),
      "currency": case.currency,
      "debtorIban": debtor_iban,
      "creditorIban": creditor_iban,
      "status": status,
      "statementRole": case.statement_role,
      "netPosted": net_posted,
      "reversalCount": case.reversal_count,
      "state": case.state.name(),
      "action": case.action,
    })
  }
  let orphan_statuses : Array[Json] = []
  for id in self.orphan_statuses {
    orphan_statuses.push(Json::string(id))
  }
  let orphan_statements : Array[Json] = []
  for id in self.orphan_statements {
    orphan_statements.push(Json::string(id))
  }
  let root = Map([])
  root.set("cases", Json::array(cases))
  root.set("orphanStatuses", Json::array(orphan_statuses))
  root.set("orphanStatements", Json::array(orphan_statements))
  Json::object(root).stringify(indent=2)
}

///|
pub fn LifecycleReport::to_markdown(self : LifecycleReport) -> String {
  let output = StringBuilder()
  output.write_string("# Payment lifecycle report\n\n")
  output.write_string("| EndToEndId | Amount | Status | Account | Net posted | State | Action |\n")
  output.write_string("|---|---|---|---|---|---|---|\n")
  for case in self.cases {
    output.write_string("| `")
    output.write_string(case.end_to_end_id)
    output.write_string("` | ")
    output.write_string(case.amount.to_string())
    output.write_string(" ")
    output.write_string(case.currency)
    output.write_string(" | ")
    output.write_string(match case.status {
      Some(value) => value
      None => "(missing)"
    })
    output.write_string(" | ")
    output.write_string(case.statement_role)
    output.write_string(" | ")
    output.write_string(match case.net_posted {
      Some(value) => value.to_string()
      None => "(not posted)"
    })
    output.write_string(" | `")
    output.write_string(case.state.name())
    output.write_string("` | ")
    output.write_string(case.action)
    output.write_string(" |\n")
  }
  output.write_string("\n## Orphan entries\n\n")
  output.write_string("- Status entries without payment: ")
  output.write_string(self.orphan_statuses.length().to_string())
  output.write_string("\n- Statement entries without payment: ")
  output.write_string(self.orphan_statements.length().to_string())
  output.write_string("\n")
  output.to_string()
}
