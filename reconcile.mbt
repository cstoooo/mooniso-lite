///|
pub struct PaymentRecord {
  end_to_end_id : String
  amount : Decimal
  currency : String
  debtor_iban : String?
  creditor_iban : String?
}

///|
pub struct StatusRecord {
  end_to_end_id : String
  status : String
}

///|
pub struct ReconciliationReport {
  matched : Int
  missing_status : Array[String]
  missing_payment : Array[String]
  status_counts : Map[String, Int]
}

///|
pub fn pain001_payment_records(
  xml_text : String,
) -> Array[PaymentRecord] raise XmlParseError {
  let data = parse_pain001_data(xml_text)
  let records : Array[PaymentRecord] = []
  for i = 0; i < data.end_to_end_ids.length(); i = i + 1 {
    match data.end_to_end_ids[i] {
      Some(id) =>
        match data.instruction_amounts[i] {
          Some(amount_text) =>
            match data.instruction_currencies[i] {
              Some(currency) =>
                match Decimal::parse(amount_text) {
                  Some(amount) => records.push({
                    end_to_end_id: id,
                    amount,
                    currency,
                    debtor_iban: data.transaction_debtor_ibans[i],
                    creditor_iban: data.transaction_creditor_ibans[i],
                  })
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  records
}

///|
pub fn status_records(xml_text : String) -> Array[StatusRecord] raise XmlParseError {
  let fields = flatten_xml(xml_text)
  let ids = texts_by_suffix(fields, "/TxInfAndSts/OrgnlEndToEndId")
  let statuses = texts_by_suffix(fields, "/TxInfAndSts/TxSts")
  let count = if ids.length() < statuses.length() {
    ids.length()
  } else {
    statuses.length()
  }
  let records : Array[StatusRecord] = []
  for i = 0; i < count; i = i + 1 {
    records.push({ end_to_end_id: ids[i], status: statuses[i], })
  }
  records
}

///|
pub fn reconcile_pain001_status(
  pain_xml : String,
  status_xml : String,
) -> ReconciliationReport raise XmlParseError {
  let payments = pain001_payment_records(pain_xml)
  let statuses = status_records(status_xml)
  let payment_ids : Map[String, Bool] = Map([])
  for payment in payments {
    if !payment_ids.contains(payment.end_to_end_id) {
      payment_ids.set(payment.end_to_end_id, true)
    }
  }
  let status_map : Map[String, String] = Map([])
  let status_counts : Map[String, Int] = Map([])
  for record in statuses {
    status_map.set(record.end_to_end_id, record.status)
    let current = match status_counts.get(record.status) {
      Some(value) => value
      None => 0
    }
    status_counts.set(record.status, current + 1)
  }
  let missing_status : Array[String] = []
  let missing_payment : Array[String] = []
  let mut matched = 0
  for payment in payments {
    if status_map.contains(payment.end_to_end_id) {
      matched += 1
    } else {
      missing_status.push(payment.end_to_end_id)
    }
  }
  for record in statuses {
    if !payment_ids.contains(record.end_to_end_id) {
      missing_payment.push(record.end_to_end_id)
    }
  }
  { matched, missing_status, missing_payment, status_counts, }
}

///|
pub fn ReconciliationReport::to_text(self : ReconciliationReport) -> String {
  let output = StringBuilder()
  output.write_string("Reconciliation report\n")
  output.write_string("Matched transactions: ")
  output.write_string(self.matched.to_string())
  output.write_string("\nMissing status entries: ")
  output.write_string(self.missing_status.length().to_string())
  output.write_string("\nMissing payment entries: ")
  output.write_string(self.missing_payment.length().to_string())
  if self.missing_status.length() > 0 {
    output.write_string("\nMissing status IDs:")
    for id in self.missing_status {
      output.write_string("\n- ")
      output.write_string(id)
    }
  }
  if self.missing_payment.length() > 0 {
    output.write_string("\nMissing payment IDs:")
    for id in self.missing_payment {
      output.write_string("\n- ")
      output.write_string(id)
    }
  }
  output.write_string("\nStatus counts:")
  for pair in self.status_counts {
    output.write_string("\n- ")
    output.write_string(pair.0)
    output.write_string(": ")
    output.write_string(pair.1.to_string())
  }
  output.to_string()
}

///|
pub fn ReconciliationReport::to_json(self : ReconciliationReport) -> String {
  let missing_status : Array[Json] = []
  for id in self.missing_status {
    missing_status.push(Json::string(id))
  }
  let missing_payment : Array[Json] = []
  for id in self.missing_payment {
    missing_payment.push(Json::string(id))
  }
  let counts = Map([])
  for pair in self.status_counts {
    counts.set(pair.0, Json::number(pair.1.to_double()))
  }
  let root = Map([])
  root.set("matched", Json::number(self.matched.to_double()))
  root.set("missingStatus", Json::array(missing_status))
  root.set("missingPayment", Json::array(missing_payment))
  root.set("statusCounts", Json::object(counts))
  Json::object(root).stringify(indent=2)
}

///|
pub fn ReconciliationReport::to_markdown(self : ReconciliationReport) -> String {
  let output = StringBuilder()
  output.write_string("# MoonPay Flow reconciliation report\n\n")
  output.write_string("- Matched transactions: ")
  output.write_string(self.matched.to_string())
  output.write_string("\n- Missing status entries: ")
  output.write_string(self.missing_status.length().to_string())
  output.write_string("\n- Missing payment entries: ")
  output.write_string(self.missing_payment.length().to_string())
  output.write_string("\n\n## Missing status IDs\n\n")
  if self.missing_status.length() == 0 {
    output.write_string("None.\n")
  } else {
    for id in self.missing_status {
      output.write_string("- ")
      output.write_string(id)
      output.write_string("\n")
    }
  }
  output.write_string("\n## Missing payment IDs\n\n")
  if self.missing_payment.length() == 0 {
    output.write_string("None.\n")
  } else {
    for id in self.missing_payment {
      output.write_string("- ")
      output.write_string(id)
      output.write_string("\n")
    }
  }
  output.write_string("\n## Status counts\n\n")
  if self.status_counts.length() == 0 {
    output.write_string("None.\n")
  } else {
    for pair in self.status_counts {
      output.write_string("- `")
      output.write_string(pair.0)
      output.write_string("`: ")
      output.write_string(pair.1.to_string())
      output.write_string("\n")
    }
  }
  output.to_string()
}
