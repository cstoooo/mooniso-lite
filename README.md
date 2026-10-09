# MoonISO Lite

MoonISO Lite is a MoonBit-native command-line tool for validating ISO 20022
`pain.001` payment initiation messages.

The project is intentionally being built in small, reviewable milestones so the
repository always stays runnable.

## Current milestone

Milestone 4: emit text, JSON and Markdown validation reports.

## Run

```bash
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
- `NbOfTxs` must match the parsed transaction count.

## Roadmap

- Milestone 5: add format validation and more regression fixtures
- Milestone 6: add control sum validation


## License

Apache-2.0
