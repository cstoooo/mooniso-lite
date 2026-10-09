# MoonISO Lite

MoonISO Lite is a MoonBit-native command-line tool for validating ISO 20022
`pain.001` payment initiation messages.

The project is intentionally being built in small, reviewable milestones so the
repository always stays runnable.

## Current milestone

Milestone 3: validate required fields, duplicate end-to-end IDs and declared
transaction counts.

## Run

```bash
moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
moon run cmd/main -- fixtures/invalid_pain001.xml
```

Expected result:

```text
Result: VALID
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

- Milestone 4: emit JSON and Markdown reports
- Milestone 5: add more fixtures and regression tests


## License

Apache-2.0
