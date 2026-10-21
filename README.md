![CI](https://github.com/cstoooo/moonpay-flow/actions/workflows/ci.yml/badge.svg)

# MoonPay Flow

MoonBit ISO 20022 payment lifecycle validator and reconciliation toolkit.

## Implementation

- Project-local XML pull reader in `xml_reader.mbt`
- Project-local fixed-point decimal module in `decimal.mbt`
- Flat XML field extractor in `flat_xml.mbt`
- Multi-message validation in `message.mbt`
- Payment reconciliation in `reconcile.mbt`
- File input through `moonbitlang/x/fs`
- CLI in `cmd/main`
- 47 unit tests and 12 fixture messages

## Status

Version: 0.5.0

Current support: `pain.001`, `pain.002`, `pacs.008`, `pacs.002` and `camt.053`.

## Run

```bash
scripts/check.sh

# Or run the commands directly:
moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
moon run cmd/main -- --format json fixtures/valid_pain001.xml
moon run cmd/main -- --format markdown fixtures/invalid_pain001.xml
moon run cmd/main -- fixtures/valid_pain002.xml
moon run cmd/main -- fixtures/valid_camt053.xml
moon run cmd/main -- reconcile fixtures/valid_pain001.xml fixtures/valid_pain002.xml
moon run cmd/main -- --list-rules
moon run cmd/main -- lifecycle fixtures/lifecycle_pain001.xml fixtures/lifecycle_pain002.xml fixtures/lifecycle_camt053.xml
```

## Rules

- Message ID is required.
- Creation date time is required.
- At least one payment instruction is required.
- Payment instruction ID is required.
- Requested execution date is required.
- End-to-end ID is required, must not exceed 35 characters and must be unique.
- Payment instruction ID must not exceed 35 characters and must be unique.
- Instructed amount and currency are required.
- `NbOfTxs` must be an unsigned integer and match the parsed transaction count.
- Date, datetime, currency and amount formats are checked.
- Payment method and charge bearer values are checked.
- IBAN checksum and BIC format are checked when present.
- `CtrlSum` must match the sum of instructed amounts when present.
- Status reports validate `OrgnlEndToEndId`, `TxSts` and duplicate status entries.
- `pacs.008` validates end-to-end IDs, settlement amounts and currencies.
- `camt.053` validates statement entries, amounts and currencies.
- `reconcile` matches `pain.001` transactions with status report entries.
- `camt.053` validates the `CdtDbtInd` credit/debit indicator.
- `--list-rules` prints the rule catalog with codes and descriptions.
- `lifecycle` classifies payment state across initiation, status and statement messages.
- Version boundaries and a full lifecycle example are documented in `docs/version-scope-and-cases.md`.

## License

Apache-2.0

## Project description

See [docs/proposal.md](docs/proposal.md).
