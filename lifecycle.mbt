///|
pub struct StatementRecord {
  end_to_end_id : String
  amount : Decimal
  currency : String
  credit_debit : String
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
  }
}

///|
pub struct LifecycleCase {
  end_to_end_id : String
  amount : Decimal
  currency : String
  status : String?
  statement_amount : Decimal?
  statement_currency : String?
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
  let fields = flatten_xml(xml_text)
  let ids = texts_by_suffix(fields, "/NtryDtls/TxDtls/Refs/EndToEndId")
  let amounts = texts_by_suffix(fields, "/Ntry/Amt")
  let amount_elements = elements_by_suffix(fields, "/Ntry/Amt")
  let indicators = texts_by_suffix(fields, "/Ntry/CdtDbtInd")
  let count = ids.length()
  let amount_count = if amounts.length() < count { amounts.length() } else { count }
  let records : Array[StatementRecord] = []
  for i = 0; i < amount_count; i = i + 1 {
    let currency = if i < amount_elements.length() {
      amount_elements[i].get_attribute("Ccy")
    } else {
      None
    }
    match Decimal::parse(amounts[i]) {
      Some(amount) =>
        match currency {
          Some(currency_code) => {
            let direction = if i < indicators.length() {
              indicators[i]
            } else {
              ""
            }
            records.push({
              end_to_end_id: ids[i],
              amount,
              currency: currency_code,
              credit_debit: direction,
            })
          }
          None => ()
        }
      None => ()
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
    StatementMismatch => "Open an exception and verify amount or currency."
    StatementBeforeFinalStatus => "Reconcile the statement entry with the current status."
  }
}

///|
fn classify_case(
  status : String?,
  statement : StatementRecord?,
  payment : PaymentRecord,
) -> LifecycleState {
  match statement {
    Some(entry) =>
      if entry.amount.compare(payment.amount) != 0 || entry.currency != payment.currency {
        return StatementMismatch
      }
    None => ()
  }
  match status {
    Some(value) =>
      if value == "ACSC" {
        match statement {
          Some(_) => Settled
          None => SettledNotPosted
        }
      } else if value == "RJCT" {
        Rejected
      } else {
        match statement {
          Some(_) => StatementBeforeFinalStatus
          None => Pending
        }
      }
    None => MissingStatus
  }
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
  let statement_map : Map[String, StatementRecord] = Map([])
  for record in statements {
    statement_map.set(record.end_to_end_id, record)
  }
  let payment_ids : Map[String, Bool] = Map([])
  let cases : Array[LifecycleCase] = []
  for payment in payments {
    payment_ids.set(payment.end_to_end_id, true)
    let status = status_map.get(payment.end_to_end_id)
    let statement = statement_map.get(payment.end_to_end_id)
    let state = classify_case(status, statement, payment)
    cases.push({
      end_to_end_id: payment.end_to_end_id,
      amount: payment.amount,
      currency: payment.currency,
      status,
      statement_amount: match statement {
        Some(entry) => Some(entry.amount)
        None => None
      },
      statement_currency: match statement {
        Some(entry) => Some(entry.currency)
        None => None
      },
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
    let statement_amount : Json = match case.statement_amount {
      Some(value) => Json::string(value.to_string())
      None => Json::null()
    }
    let statement_currency : Json = match case.statement_currency {
      Some(value) => Json::string(value)
      None => Json::null()
    }
    cases.push({
      "endToEndId": case.end_to_end_id,
      "amount": case.amount.to_string(),
      "currency": case.currency,
      "status": status,
      "statementAmount": statement_amount,
      "statementCurrency": statement_currency,
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
  output.write_string("| EndToEndId | Amount | Status | State | Action |\n")
  output.write_string("|---|---|---|---|---|\n")
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
