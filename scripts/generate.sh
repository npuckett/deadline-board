#!/bin/bash
# Regenerate Deadlines.xcodeproj from project.yml.
# Run after any change to project.yml or after adding/removing source files.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate
echo "Generated Deadlines.xcodeproj"
