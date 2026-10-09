///|
/// Validation result for one pain.001 document.
pub struct Diagnostic {
  code : String
  path : String
  message : String
}

///|
pub struct ValidationReport {
  summary : Pain001Summary
  diagnostics : Array[Diagnostic]
}

///|
fn text_present(value : String?) -> Bool {
  match value {
    Some(text) => text != ""
    None => false
  }
}

///|
fn push_diagnostic(
  diagnostics : Array[Diagnostic],
  code : String,
  path : String,
  message : String,
) -> Unit {
  diagnostics.push({ code, path, message, })
}


///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_iso_date(value : String) -> Bool {
  if value.length() != 10 {
    return false
  }
  for i = 0; i < value.length(); i = i + 1 {
    let c = value[i].unsafe_to_char()
    if i == 4 || i == 7 {
      if c != '-' {
        return false
      }
    } else if !is_digit(c) {
      return false
    }
  }
  true
}

///|
fn is_iso_datetime(value : String) -> Bool {
  if value.length() < 19 {
    return false
  }
  for i = 0; i < 19; i = i + 1 {
    let c = value[i].unsafe_to_char()
    if i == 4 || i == 7 {
      if c != '-' {
        return false
      }
    } else if i == 10 {
      if c != 'T' {
        return false
      }
    } else if i == 13 || i == 16 {
      if c != ':' {
        return false
      }
    } else if !is_digit(c) {
      return false
    }
  }
  true
}

///|
fn is_currency(value : String) -> Bool {
  if value.length() != 3 {
    return false
  }
  for c in value {
    if c < 'A' || c > 'Z' {
      return false
    }
  }
  true
}

///|
fn is_decimal_amount(value : String) -> Bool {
  if value == "" || value[0] == '.' || value[value.length() - 1] == '.' {
    return false
  }
  let mut dot_count = 0
  let mut digit_count = 0
  for c in value {
    if is_digit(c) {
      digit_count += 1
    } else if c == '.' {
      dot_count += 1
    } else {
      return false
    }
  }
  digit_count > 0 && dot_count <= 1
}

///|
fn is_unsigned_integer(value : String) -> Bool {
  if value == "" {
    return false
  }
  for c in value {
    if !is_digit(c) {
      return false
    }
  }
  true
}

///|
fn indexed_path(base : String, index : Int) -> String {
  base + "[" + index.to_string() + "]"
}

///|
pub fn validate_pain001(
  xml_text : String,
) -> ValidationReport raise @xml.XmlError {
  let data = parse_pain001_data(xml_text)
  let diagnostics : Array[Diagnostic] = []
  if !text_present(data.summary.message_id) {
    push_diagnostic(
      diagnostics,
      "MSG_ID_MISSING",
      "GrpHdr/MsgId",
      "Message ID is required.",
    )
  }
  if !text_present(data.summary.creation_datetime) {
    push_diagnostic(
      diagnostics,
      "CREATION_TIME_MISSING",
      "GrpHdr/CreDtTm",
      "Creation date time is required.",
    )
  } else {
    match data.summary.creation_datetime {
      Some(value) =>
        if !is_iso_datetime(value) {
          push_diagnostic(
            diagnostics,
            "CREATION_TIME_INVALID",
            "GrpHdr/CreDtTm",
            "Creation date time must use ISO 8601 datetime format.",
          )
        }
      None => ()
    }
  }
  if data.summary.payment_instruction_count == 0 {
    push_diagnostic(
      diagnostics,
      "PAYMENT_INSTRUCTION_MISSING",
      "PmtInf",
      "At least one payment instruction is required.",
    )
  }
  for i = 0; i < data.payment_instruction_ids.length(); i = i + 1 {
    if !text_present(data.payment_instruction_ids[i]) {
      push_diagnostic(
        diagnostics,
        "PAYMENT_INSTRUCTION_ID_MISSING",
        indexed_path("PmtInf/PmtInfId", i),
        "Payment instruction ID is required.",
      )
    }
    if !text_present(data.execution_dates[i]) {
      push_diagnostic(
        diagnostics,
        "EXECUTION_DATE_MISSING",
        indexed_path("PmtInf/ReqdExctnDt", i),
        "Requested execution date is required.",
      )
    } else {
      match data.execution_dates[i] {
        Some(value) =>
          if !is_iso_date(value) {
            push_diagnostic(
              diagnostics,
              "EXECUTION_DATE_INVALID",
              indexed_path("PmtInf/ReqdExctnDt", i),
              "Requested execution date must use ISO 8601 date format.",
            )
          }
        None => ()
      }
    }
  }
  let seen_end_to_end_ids : Map[String, Bool] = Map([])
  for i = 0; i < data.end_to_end_ids.length(); i = i + 1 {
    let end_to_end_id = data.end_to_end_ids[i]
    if !text_present(end_to_end_id) {
      push_diagnostic(
        diagnostics,
        "END_TO_END_ID_MISSING",
        indexed_path("CdtTrfTxInf/PmtId/EndToEndId", i),
        "End-to-end ID is required.",
      )
    } else {
      match end_to_end_id {
        Some(value) => {
          if seen_end_to_end_ids.contains(value) {
            push_diagnostic(
              diagnostics,
              "END_TO_END_ID_DUPLICATE",
              indexed_path("CdtTrfTxInf/PmtId/EndToEndId", i),
              "End-to-end ID is duplicated: " + value,
            )
          } else {
            seen_end_to_end_ids.set(value, true)
          }
        }
        None => ()
      }
    }
    if !text_present(data.instruction_amounts[i]) {
      push_diagnostic(
        diagnostics,
        "INSTRUCTION_AMOUNT_MISSING",
        indexed_path("CdtTrfTxInf/Amt/InstdAmt", i),
        "Instructed amount is required.",
      )
    } else {
      match data.instruction_amounts[i] {
        Some(value) =>
          if !is_decimal_amount(value) {
            push_diagnostic(
              diagnostics,
              "INSTRUCTION_AMOUNT_INVALID",
              indexed_path("CdtTrfTxInf/Amt/InstdAmt", i),
              "Instructed amount must be a positive decimal number.",
            )
          }
        None => ()
      }
    }
    if !text_present(data.instruction_currencies[i]) {
      push_diagnostic(
        diagnostics,
        "INSTRUCTION_CURRENCY_MISSING",
        indexed_path("CdtTrfTxInf/Amt/InstdAmt/@Ccy", i),
        "Instruction currency is required.",
      )
    } else {
      match data.instruction_currencies[i] {
        Some(value) =>
          if !is_currency(value) {
            push_diagnostic(
              diagnostics,
              "INSTRUCTION_CURRENCY_INVALID",
              indexed_path("CdtTrfTxInf/Amt/InstdAmt/@Ccy", i),
              "Instruction currency must be a three-letter uppercase code.",
            )
          }
        None => ()
      }
    }
  }
  match data.declared_transaction_count {
    Some(declared) => {
      if !is_unsigned_integer(declared) {
        push_diagnostic(
          diagnostics,
          "TRANSACTION_COUNT_INVALID",
          "GrpHdr/NbOfTxs",
          "Declared transaction count must be an unsigned integer.",
        )
      } else if declared != data.summary.transaction_count.to_string() {
        push_diagnostic(
          diagnostics,
          "TRANSACTION_COUNT_MISMATCH",
          "GrpHdr/NbOfTxs",
          "Declared transaction count does not match parsed transactions.",
        )
      }
    }
    None => ()
  }
  { summary: data.summary, diagnostics, }
}

///|
pub fn ValidationReport::is_valid(self : ValidationReport) -> Bool {
  self.diagnostics.length() == 0
}

///|
pub fn ValidationReport::to_text(self : ValidationReport) -> String {
  let output = StringBuilder()
  output.write_string(self.summary.to_text())
  output.write_string("\nResult: ")
  if self.is_valid() {
    output.write_string("VALID")
  } else {
    output.write_string("INVALID (")
    output.write_string(self.diagnostics.length().to_string())
    output.write_string(" issue(s))")
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
pub fn ValidationReport::to_json(self : ValidationReport) -> String {
  let diagnostics : Array[Json] = []
  for diagnostic in self.diagnostics {
    let item : Json = {
      "code": diagnostic.code,
      "path": diagnostic.path,
      "message": diagnostic.message,
    }
    diagnostics.push(item)
  }
  let message_id : Json = match self.summary.message_id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let creation_datetime : Json = match self.summary.creation_datetime {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let summary = Map([])
  summary.set("messageId", message_id)
  summary.set("creationDateTime", creation_datetime)
  summary.set(
    "paymentInstructionCount",
    Json::number(self.summary.payment_instruction_count.to_double()),
  )
  summary.set(
    "transactionCount",
    Json::number(self.summary.transaction_count.to_double()),
  )
  let root = Map([])
  root.set("valid", Json::boolean(self.is_valid()))
  root.set("summary", Json::object(summary))
  root.set("diagnostics", Json::array(diagnostics))
  Json::object(root).stringify(indent=2)
}

///|
pub fn ValidationReport::to_markdown(self : ValidationReport) -> String {
  let output = StringBuilder()
  output.write_string("# MoonISO Lite validation report\n\n")
  output.write_string("**Result:** ")
  if self.is_valid() {
    output.write_string("VALID\n\n")
  } else {
    output.write_string("INVALID\n\n")
  }
  output.write_string("## Summary\n\n")
  output.write_string("- Message ID: ")
  output.write_string(match self.summary.message_id {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("\n- Creation time: ")
  output.write_string(match self.summary.creation_datetime {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("\n- Payment instructions: ")
  output.write_string(self.summary.payment_instruction_count.to_string())
  output.write_string("\n- Transactions: ")
  output.write_string(self.summary.transaction_count.to_string())
  output.write_string("\n\n## Diagnostics\n\n")
  if self.is_valid() {
    output.write_string("No issues found.\n")
  } else {
    output.write_string("| Code | Path | Message |\n")
    output.write_string("|---|---|---|\n")
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
