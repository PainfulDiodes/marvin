#!/usr/bin/env bash

# Clean build output for BeanBoard target

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
rm -rf "$SCRIPT_DIR/output"/*
