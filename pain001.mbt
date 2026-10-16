///|
/// Basic information extracted from an ISO 20022 pain.001 message.
pub struct Pain001Summary {
  message_id : String?
  creation_datetime : String?
  payment_instruction_count : Int
  transaction_count : Int
}

///|
/// Internal parse result used by summary and validation milestones.
priv struct Pain001Data {
  summary : Pain001Summary
  payment_instruction_ids : Array[String?]
  execution_dates : Array[String?]
  end_to_end_ids : Array[String?]
  instruction_amounts : Array[String?]
  instruction_currencies : Array[String?]
  payment_methods : Array[String?]
  charge_bearers : Array[String?]
  debtor_ibans : Array[String?]
  debtor_bics : Array[String?]
  creditor_ibans : Array[String?]
  creditor_bics : Array[String?]
  declared_transaction_count : String?
  declared_control_sum : String?
}

///|
fn path_equals(path : Array[String], expected : Array[String]) -> Bool {
  if path.length() != expected.length() {
    return false
  }
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn set_last(values : Array[String?], value : String) -> Unit {
  if values.length() > 0 {
    values[values.length() - 1] = Some(value)
  }
}

///|
fn parse_pain001_data(xml_text : String) -> Pain001Data raise XmlParseError {
  let reader = XmlReader::from_string(xml_text)
  let path : Array[String] = []
  let mut message_id : String? = None
  let mut creation_datetime : String? = None
  let mut declared_transaction_count : String? = None
  let mut declared_control_sum : String? = None
  let payment_instruction_ids : Array[String?] = []
  let execution_dates : Array[String?] = []
  let end_to_end_ids : Array[String?] = []
  let instruction_amounts : Array[String?] = []
  let instruction_currencies : Array[String?] = []
  let payment_methods : Array[String?] = []
  let charge_bearers : Array[String?] = []
  let debtor_ibans : Array[String?] = []
  let debtor_bics : Array[String?] = []
  let creditor_ibans : Array[String?] = []
  let creditor_bics : Array[String?] = []
  for ;; {
    let event = reader.read_event()
    match event.kind {
      Start(element) => {
        path.push(element.name)
        if path_equals(path, ["Document", "CstmrCdtTrfInitn", "PmtInf"]) {
          payment_instruction_ids.push(None)
          execution_dates.push(None)
          payment_methods.push(None)
          charge_bearers.push(None)
          debtor_ibans.push(None)
          debtor_bics.push(None)
        }
        if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "CdtTrfTxInf",
          ],
        ) {
          end_to_end_ids.push(None)
          instruction_amounts.push(None)
          instruction_currencies.push(None)
          creditor_ibans.push(None)
          creditor_bics.push(None)
        }
        if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "CdtTrfTxInf",
            "Amt",
            "InstdAmt",
          ],
        ) {
          if instruction_currencies.length() > 0 {
            instruction_currencies[instruction_currencies.length() - 1] =
              element.get("Ccy")
          }
        }
      }
      Empty(element) => {
        path.push(element.name)
        if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "CdtTrfTxInf",
            "Amt",
            "InstdAmt",
          ],
        ) {
          if instruction_currencies.length() > 0 {
            instruction_currencies[instruction_currencies.length() - 1] =
              element.get("Ccy")
          }
        }
        let _ = path.remove(path.length() - 1)
      }
      Text(content) => {
        if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "MsgId"],
        ) {
          message_id = Some(content)
        } else if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "CreDtTm"],
        ) {
          creation_datetime = Some(content)
        } else if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "NbOfTxs"],
        ) {
          declared_transaction_count = Some(content)
        } else if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "CtrlSum"],
        ) {
          declared_control_sum = Some(content)
        } else if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "PmtInf", "PmtInfId"],
        ) {
          set_last(payment_instruction_ids, content)
        } else if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "PmtInf", "ReqdExctnDt"],
        ) {
          set_last(execution_dates, content)
        } else if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "PmtInf", "PmtMtd"],
        ) {
          set_last(payment_methods, content)
        } else if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "PmtInf", "ChrgBr"],
        ) {
          set_last(charge_bearers, content)
        } else if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "DbtrAcct",
            "Id",
            "IBAN",
          ],
        ) {
          set_last(debtor_ibans, content)
        } else if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "DbtrAgt",
            "FinInstnId",
            "BIC",
          ],
        ) {
          set_last(debtor_bics, content)
        } else if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "CdtTrfTxInf",
            "PmtId",
            "EndToEndId",
          ],
        ) {
          set_last(end_to_end_ids, content)
        } else if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "CdtTrfTxInf",
            "CdtrAcct",
            "Id",
            "IBAN",
          ],
        ) {
          set_last(creditor_ibans, content)
        } else if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "CdtTrfTxInf",
            "CdtrAgt",
            "FinInstnId",
            "BIC",
          ],
        ) {
          set_last(creditor_bics, content)
        } else if path_equals(
          path,
          [
            "Document",
            "CstmrCdtTrfInitn",
            "PmtInf",
            "CdtTrfTxInf",
            "Amt",
            "InstdAmt",
          ],
        ) {
          set_last(instruction_amounts, content)
        }
      }
      End(_) => {
        if path.length() > 0 {
          let _ = path.remove(path.length() - 1)
        }
      }
      Eof => break
    }
  }
  let summary = {
    message_id,
    creation_datetime,
    payment_instruction_count: payment_instruction_ids.length(),
    transaction_count: end_to_end_ids.length(),
  }
  {
    summary,
    payment_instruction_ids,
    execution_dates,
    end_to_end_ids,
    instruction_amounts,
    instruction_currencies,
    payment_methods,
    charge_bearers,
    debtor_ibans,
    debtor_bics,
    creditor_ibans,
    creditor_bics,
    declared_transaction_count,
    declared_control_sum,
  }
}

///|
pub fn summarize_pain001(
  xml_text : String,
) -> Pain001Summary raise XmlParseError {
  parse_pain001_data(xml_text).summary
}

///|
pub fn Pain001Summary::to_text(self : Pain001Summary) -> String {
  let message_id = match self.message_id {
    Some(value) => value
    None => "(missing)"
  }
  let creation_datetime = match self.creation_datetime {
    Some(value) => value
    None => "(missing)"
  }
  "Message ID: " +
  message_id +
  "\nCreation time: " +
  creation_datetime +
  "\nPayment instructions: " +
  self.payment_instruction_count.to_string() +
  "\nTransactions: " +
  self.transaction_count.to_string()
}
