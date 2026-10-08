# MoonISO Lite

MoonISO Lite is a MoonBit-native command-line tool for validating ISO 20022
`pain.001` payment initiation messages.

The project is intentionally being built in small, reviewable milestones so the
repository always stays runnable.

## Current milestone

Milestone 2: read a `pain.001.xml` file and print a basic summary.

## Run

```bash
moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
```

Expected summary:

```text
Message ID: MSG-001
Creation time: 2026-10-08T12:00:00Z
Payment instructions: 1
Transactions: 2
```

## Roadmap

- Milestone 3: validate required fields and basic business rules
- Milestone 4: emit JSON and Markdown reports
- Milestone 5: add more fixtures and regression tests

## License

Apache-2.0
