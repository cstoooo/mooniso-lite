# MoonISO Lite

MoonISO Lite is a MoonBit-native command-line tool for validating ISO 20022
`pain.001` payment initiation messages.

The project is intentionally being built in small, reviewable milestones so the
repository always stays runnable.

## Current milestone

Milestone 6: validate the declared control sum against instructed amounts.

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

## Rules implemented

- Message ID is required.
- Creation date time is required.
- At least one payment instruction is required.
- Payment instruction ID is required.
- Requested execution date is required.
- End-to-end ID is required and must be unique.
- Instructed amount and currency are required.
- `NbOfTxs` must be an unsigned integer and match the parsed transaction count.
- Dates, datetime, currency and amount formats are checked.
- `CtrlSum` must match the sum of instructed amounts when present.

## Roadmap



## License

Apache-2.0
