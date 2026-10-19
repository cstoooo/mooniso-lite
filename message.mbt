///|
pub(all) enum MessageKind {
  Pain001
  Pain002
  Pacs008
  Pacs002
  Camt053
  Unknown
}

///|
pub fn MessageKind::name(self : MessageKind) -> String {
  match self {
    Pain001 => "pain.001"
    Pain002 => "pain.002"
    Pacs008 => "pacs.008"
    Pacs002 => "pacs.002"
    Camt053 => "camt.053"
    Unknown => "unknown"
  }
}

///|
pub struct MessageInfo {
  kind : MessageKind
  message_id : String?
  creation_datetime : String?
  original_message_id : String?
  entry_count : Int
}

///|
pub struct MessageValidation {
  info : MessageInfo
  diagnostics : Array[Diagnostic]
}

///|
fn first_optional(values : Array[String?]) -> String? {
  for value in values {
    match value {
      Some(text) => return Some(text)
      None => ()
    }
  }
  None
}

///|
fn detect_from_fields(fields : Array[XmlField]) -> MessageKind {
  for field in fields {
    if field.text is None {
      if field.path.has_suffix("/CstmrCdtTrfInitn") {
        return Pain001
      } else if field.path.has_suffix("/CstmrPmtStsRpt") {
        return Pain002
      } else if field.path.has_suffix("/FIToFICstmrCdtTrf") {
        return Pacs008
      } else if field.path.has_suffix("/FIToFIPmtStsRpt") {
        return Pacs002
      } else if field.path.has_suffix("/BkToCstmrStmt") {
        return Camt053
      }
    }
  }
  Unknown
}

///|
pub fn detect_message_kind(xml_text : String) -> MessageKind raise XmlParseError {
  detect_from_fields(flatten_xml(xml_text))
}

///|
fn is_valid_status(value : String) -> Bool {
  value == "ACCP" ||
  value == "ACSC" ||
  value == "ACSP" ||
  value == "ACTC" ||
  value == "ACWC" ||
  value == "PDNG" ||
  value == "RCVD" ||
  value == "RJCT"
}

///|
fn build_info(kind : MessageKind, fields : Array[XmlField]) -> MessageInfo {
  let original_message_id = first_optional([
    first_text_by_suffix(fields, "/OrgnlGrpInfAndSts/OrgnlMsgId"),
    first_text_by_suffix(fields, "/OrgnlGrpInf/OrgnlMsgId"),
  ])
  let entry_count = match kind {
    Pain002 | Pacs002 => elements_by_suffix(fields, "/TxInfAndSts").length()
    Pacs008 => elements_by_suffix(fields, "/CdtTrfTxInf").length()
    Camt053 => elements_by_suffix(fields, "/Ntry").length()
    Pain001 => 0
    Unknown => 0
  }
  {
    kind,
    message_id: first_text_by_suffix(fields, "/GrpHdr/MsgId"),
    creation_datetime: first_text_by_suffix(fields, "/GrpHdr/CreDtTm"),
    original_message_id,
    entry_count,
  }
}

///|
pub fn validate_message(
  xml_text : String,
) -> MessageValidation raise XmlParseError {
  let kind = detect_message_kind(xml_text)
  if kind is Pain001 {
    let report = validate_pain001(xml_text)
    return {
      info: {
        kind,
        message_id: report.summary.message_id,
        creation_datetime: report.summary.creation_datetime,
        original_message_id: None,
        entry_count: report.summary.transaction_count,
      },
      diagnostics: report.diagnostics,
    }
  }
  let fields = flatten_xml(xml_text)
  let info = build_info(kind, fields)
  let diagnostics : Array[Diagnostic] = []
  if kind is Unknown {
    push_diagnostic(
      diagnostics,
      "UNKNOWN_MESSAGE_TYPE",
      "Document",
      "Unsupported ISO 20022 message type.",
    )
    return { info, diagnostics, }
  }
  if !text_present(info.message_id) {
    push_diagnostic(
      diagnostics,
      "MSG_ID_MISSING",
      "GrpHdr/MsgId",
      "Message ID is required.",
    )
  }
  if !text_present(info.creation_datetime) {
    push_diagnostic(
      diagnostics,
      "CREATION_TIME_MISSING",
      "GrpHdr/CreDtTm",
      "Creation date time is required.",
    )
  }
  if info.entry_count == 0 {
    push_diagnostic(
      diagnostics,
      "ENTRY_MISSING",
      "Message",
      "At least one message entry is required.",
    )
  }
  match kind {
    Pain002 | Pacs002 => {
      let status_ids = texts_by_suffix(fields, "/TxInfAndSts/OrgnlEndToEndId")
      let statuses = texts_by_suffix(fields, "/TxInfAndSts/TxSts")
      if status_ids.length() != statuses.length() {
        push_diagnostic(
          diagnostics,
          "STATUS_ENTRY_INCOMPLETE",
          "TxInfAndSts",
          "Each status entry must contain both an original end-to-end ID and a status.",
        )
      }
      let seen : Map[String, Bool] = Map([])
      for i = 0; i < status_ids.length(); i = i + 1 {
        let id = status_ids[i]
        if seen.contains(id) {
          push_diagnostic(
            diagnostics,
            "STATUS_ID_DUPLICATE",
            "TxInfAndSts/OrgnlEndToEndId",
            "Original end-to-end ID is duplicated: " + id,
          )
        } else {
          seen.set(id, true)
        }
      }
      for status in statuses {
        if !is_valid_status(status) {
          push_diagnostic(
            diagnostics,
            "STATUS_CODE_INVALID",
            "TxInfAndSts/TxSts",
            "Unknown transaction status: " + status,
          )
        }
      }
    }
    Pacs008 => {
      let ids = texts_by_suffix(fields, "/CdtTrfTxInf/PmtId/EndToEndId")
      let amounts = elements_by_suffix(fields, "/CdtTrfTxInf/IntrBkSttlmAmt")
      let seen : Map[String, Bool] = Map([])
      for id in ids {
        if seen.contains(id) {
          push_diagnostic(
            diagnostics,
            "PACS_END_TO_END_ID_DUPLICATE",
            "CdtTrfTxInf/PmtId/EndToEndId",
            "End-to-end ID is duplicated: " + id,
          )
        } else {
          seen.set(id, true)
        }
      }
      for field in amounts {
        match field.text {
          Some(value) =>
            if Decimal::parse(value) is None {
              push_diagnostic(
                diagnostics,
                "SETTLEMENT_AMOUNT_INVALID",
                "CdtTrfTxInf/IntrBkSttlmAmt",
                "Settlement amount must be a decimal with up to two decimal places.",
              )
            }
          None => ()
        }
        match field.get_attribute("Ccy") {
          Some(value) =>
            if !is_currency(value) {
              push_diagnostic(
                diagnostics,
                "SETTLEMENT_CURRENCY_INVALID",
                "CdtTrfTxInf/IntrBkSttlmAmt/@Ccy",
                "Settlement currency must be a three-letter uppercase code.",
              )
            }
          None =>
            push_diagnostic(
              diagnostics,
              "SETTLEMENT_CURRENCY_MISSING",
              "CdtTrfTxInf/IntrBkSttlmAmt/@Ccy",
              "Settlement currency is required.",
            )
        }
      }
    }
    Camt053 => {
      let amount_fields = elements_by_suffix(fields, "/Ntry/Amt")
      for field in amount_fields {
        match field.text {
          Some(value) =>
            if Decimal::parse(value) is None {
              push_diagnostic(
                diagnostics,
                "STATEMENT_AMOUNT_INVALID",
                "Ntry/Amt",
                "Statement entry amount must be a decimal with up to two decimal places.",
              )
            }
          None => ()
        }
        match field.get_attribute("Ccy") {
          Some(value) =>
            if !is_currency(value) {
              push_diagnostic(
                diagnostics,
                "STATEMENT_CURRENCY_INVALID",
                "Ntry/Amt/@Ccy",
                "Statement currency must be a three-letter uppercase code.",
              )
            }
          None =>
            push_diagnostic(
              diagnostics,
              "STATEMENT_CURRENCY_MISSING",
              "Ntry/Amt/@Ccy",
              "Statement currency is required.",
            )
        }
      }
    }
    Pain001 | Unknown => ()
  }
  { info, diagnostics, }
}

///|
pub fn MessageValidation::is_valid(self : MessageValidation) -> Bool {
  self.diagnostics.length() == 0
}

///|
pub fn MessageValidation::to_text(self : MessageValidation) -> String {
  let output = StringBuilder()
  output.write_string("Message type: ")
  output.write_string(self.info.kind.name())
  output.write_string("\nMessage ID: ")
  output.write_string(match self.info.message_id {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("\nCreation time: ")
  output.write_string(match self.info.creation_datetime {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("\nOriginal message ID: ")
  output.write_string(match self.info.original_message_id {
    Some(value) => value
    None => "(not present)"
  })
  output.write_string("\nEntries: ")
  output.write_string(self.info.entry_count.to_string())
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
pub fn MessageValidation::to_json(self : MessageValidation) -> String {
  let diagnostics : Array[Json] = []
  for diagnostic in self.diagnostics {
    let item : Json = {
      "code": diagnostic.code,
      "path": diagnostic.path,
      "message": diagnostic.message,
    }
    diagnostics.push(item)
  }
  let message_id : Json = match self.info.message_id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let creation_datetime : Json = match self.info.creation_datetime {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let original_message_id : Json = match self.info.original_message_id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let summary = Map([])
  summary.set("messageType", Json::string(self.info.kind.name()))
  summary.set("messageId", message_id)
  summary.set("creationDateTime", creation_datetime)
  summary.set("originalMessageId", original_message_id)
  summary.set("entryCount", Json::number(self.info.entry_count.to_double()))
  let root = Map([])
  root.set("valid", Json::boolean(self.is_valid()))
  root.set("summary", Json::object(summary))
  root.set("diagnostics", Json::array(diagnostics))
  Json::object(root).stringify(indent=2)
}

///|
pub fn MessageValidation::to_markdown(self : MessageValidation) -> String {
  let output = StringBuilder()
  output.write_string("# MoonISO validation report\n\n")
  output.write_string("**Message type:** ")
  output.write_string(self.info.kind.name())
  output.write_string("\n\n**Result:** ")
  if self.is_valid() {
    output.write_string("VALID\n")
  } else {
    output.write_string("INVALID\n")
  }
  output.write_string("\n## Summary\n\n")
  output.write_string("- Message ID: ")
  output.write_string(match self.info.message_id {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("\n- Creation time: ")
  output.write_string(match self.info.creation_datetime {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("\n- Original message ID: ")
  output.write_string(match self.info.original_message_id {
    Some(value) => value
    None => "(not present)"
  })
  output.write_string("\n- Entries: ")
  output.write_string(self.info.entry_count.to_string())
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
