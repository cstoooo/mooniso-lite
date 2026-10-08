///|
/// Basic information extracted from an ISO 20022 pain.001 message.
pub struct Pain001Summary {
  message_id : String?
  creation_datetime : String?
  payment_instruction_count : Int
  transaction_count : Int
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
/// Parse a pain.001 XML document and collect the small summary needed by the
/// first parsing milestone. Full validation and typed transaction models are
/// intentionally left to later milestones.
pub fn summarize_pain001(
  xml_text : String,
) -> Pain001Summary raise @xml.XmlError {
  let reader = @xml.Reader::from_string(xml_text)
  let path : Array[String] = []
  let mut message_id : String? = None
  let mut creation_datetime : String? = None
  let mut payment_instruction_count = 0
  let mut transaction_count = 0
  for ;; {
    let event = reader.read_event()
    match event.kind {
      Start(element) => {
        path.push(element.name)
        if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "MsgId"],
        ) {
          // The text event immediately following this element carries the value.
        }
        if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "CreDtTm"],
        ) {
          // The text event immediately following this element carries the value.
        }
        if path_equals(path, ["Document", "CstmrCdtTrfInitn", "PmtInf"]) {
          payment_instruction_count += 1
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
          transaction_count += 1
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
          ],
        ) {
          transaction_count += 1
        }
        let _ = path.remove(path.length() - 1)
      }
      Text(content) => {
        if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "MsgId"],
        ) {
          message_id = Some(content)
        }
        if path_equals(
          path,
          ["Document", "CstmrCdtTrfInitn", "GrpHdr", "CreDtTm"],
        ) {
          creation_datetime = Some(content)
        }
      }
      End(_) => {
        if path.length() > 0 {
          let _ = path.remove(path.length() - 1)
        }
      }
      Eof => break
      _ => ()
    }
  }
  {
    message_id,
    creation_datetime,
    payment_instruction_count,
    transaction_count,
  }
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
