![CI](https://github.com/cstoooo/mooniso-lite/actions/workflows/ci.yml/badge.svg)

# MoonISO Lite

MoonBit command-line validator for ISO 20022 `pain.001` payment messages.

## Implementation

- Project-local XML pull reader in `xml_reader.mbt`
- Project-local fixed-point decimal module in `decimal.mbt`
- Rule and report module in `validation.mbt`
- File input through `moonbitlang/x/fs`
- CLI in `cmd/main`
- 15 unit tests and 5 fixture messages

## Status

Version: 0.3.0

Current support: `pain.001.001.03` core fields and rules.

## Run

```bash
scripts/check.sh

# Or run the commands directly:
moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
moon run cmd/main -- --format json fixtures/valid_pain001.xml
moon run cmd/main -- --format markdown fixtures/invalid_pain001.xml
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

## License

Apache-2.0

## Project description

See [docs/proposal.md](docs/proposal.md).
