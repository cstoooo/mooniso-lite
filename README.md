# MoonISO Lite

MoonISO Lite is a MoonBit-native command-line tool for validating ISO 20022
`pain.001` payment initiation messages.

The project is intentionally being built in small, reviewable milestones so the
repository always stays runnable.

## Current milestone

Milestone 1: runnable project skeleton and CLI help.

## Run

```bash
moon check
moon run cmd/main -- --help
```

Expected output starts with:

```text
MoonISO Lite 0.1.0
```

## Roadmap

- Milestone 2: parse a `pain.001.xml` file
- Milestone 3: validate required fields and basic business rules
- Milestone 4: emit JSON and Markdown reports
- Milestone 5: add fixtures and regression tests

## License

Apache-2.0
