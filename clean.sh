#!/usr/bin/env bash

# Clean all target build outputs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/targets/beanzee/clean.sh"
"$SCRIPT_DIR/targets/beanboard/clean.sh"
