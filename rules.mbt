///|
pub struct RuleInfo {
  code : String
  description : String
}

///|
pub fn rule_catalog() -> Array[RuleInfo] {
  [
    { code: "MSG_ID_MISSING", description: "Message ID is required." },
    { code: "MSG_ID_TOO_LONG", description: "Message ID must not exceed 35 characters." },
    { code: "CREATION_TIME_MISSING", description: "Creation date time is required." },
    { code: "CREATION_TIME_INVALID", description: "Creation date time must use ISO 8601 format." },
    { code: "PAYMENT_INSTRUCTION_MISSING", description: "At least one payment instruction is required." },
    { code: "PAYMENT_INSTRUCTION_ID_MISSING", description: "Payment instruction ID is required." },
    { code: "PAYMENT_INSTRUCTION_ID_TOO_LONG", description: "Payment instruction ID must not exceed 35 characters." },
    { code: "PAYMENT_INSTRUCTION_ID_DUPLICATE", description: "Payment instruction IDs must be unique." },
    { code: "EXECUTION_DATE_MISSING", description: "Requested execution date is required." },
    { code: "EXECUTION_DATE_INVALID", description: "Requested execution date must use ISO 8601 format." },
    { code: "PAYMENT_METHOD_INVALID", description: "Payment method must be TRF, CHK or TRA." },
    { code: "CHARGE_BEARER_INVALID", description: "Charge bearer must be DEBT, CRED, SHAR or SLEV." },
    { code: "DEBTOR_IBAN_INVALID", description: "Debtor IBAN is invalid." },
    { code: "DEBTOR_BIC_INVALID", description: "Debtor BIC is invalid." },
    { code: "END_TO_END_ID_MISSING", description: "End-to-end ID is required." },
    { code: "END_TO_END_ID_TOO_LONG", description: "End-to-end ID must not exceed 35 characters." },
    { code: "END_TO_END_ID_DUPLICATE", description: "End-to-end IDs must be unique." },
    { code: "INSTRUCTION_AMOUNT_MISSING", description: "Instructed amount is required." },
    { code: "INSTRUCTION_AMOUNT_INVALID", description: "Instructed amount must be a decimal with up to two decimals." },
    { code: "INSTRUCTION_AMOUNT_NOT_POSITIVE", description: "Instructed amount must be greater than zero." },
    { code: "INSTRUCTION_CURRENCY_MISSING", description: "Instruction currency is required." },
    { code: "INSTRUCTION_CURRENCY_INVALID", description: "Instruction currency must be a three-letter code." },
    { code: "CONTROL_SUM_INVALID", description: "Declared control sum is invalid." },
    { code: "CONTROL_SUM_MISMATCH", description: "Control sum must match instructed amounts." },
    { code: "TRANSACTION_COUNT_INVALID", description: "Transaction count must be an unsigned integer." },
    { code: "TRANSACTION_COUNT_MISMATCH", description: "Transaction count must match parsed transactions." },
    { code: "CREDITOR_IBAN_INVALID", description: "Creditor IBAN is invalid." },
    { code: "CREDITOR_BIC_INVALID", description: "Creditor BIC is invalid." },
    { code: "UNKNOWN_MESSAGE_TYPE", description: "Message type is not supported." },
    { code: "ENTRY_MISSING", description: "At least one message entry is required." },
    { code: "STATUS_ENTRY_INCOMPLETE", description: "Status entry must contain an original ID and a status." },
    { code: "STATUS_ID_DUPLICATE", description: "Original end-to-end ID must be unique in a status report." },
    { code: "STATUS_CODE_INVALID", description: "Transaction status code is invalid." },
    { code: "SETTLEMENT_AMOUNT_MISSING", description: "Settlement amount value is required." },
    { code: "SETTLEMENT_AMOUNT_INVALID", description: "Settlement amount is invalid." },
    { code: "SETTLEMENT_AMOUNT_NOT_POSITIVE", description: "Settlement amount must be greater than zero." },
    { code: "SETTLEMENT_CURRENCY_MISSING", description: "Settlement currency is required." },
    { code: "SETTLEMENT_CURRENCY_INVALID", description: "Settlement currency is invalid." },
    { code: "PACS_END_TO_END_ID_DUPLICATE", description: "pacs.008 end-to-end IDs must be unique." },
    { code: "STATEMENT_AMOUNT_MISSING", description: "Statement amount value is required." },
    { code: "STATEMENT_AMOUNT_INVALID", description: "Statement amount is invalid." },
    { code: "STATEMENT_CURRENCY_MISSING", description: "Statement currency is required." },
    { code: "STATEMENT_CURRENCY_INVALID", description: "Statement currency is invalid." },
    { code: "ENTRY_CREDIT_DEBIT_MISSING", description: "Statement entry must contain CdtDbtInd." },
    { code: "ENTRY_CREDIT_DEBIT_INVALID", description: "CdtDbtInd must be CRDT or DBIT." },
  ]
}
