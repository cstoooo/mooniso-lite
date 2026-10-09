#!/usr/bin/env bash
set -euo pipefail

moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
moon run cmd/main -- fixtures/invalid_pain001.xml
