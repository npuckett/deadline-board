#!/bin/bash
# One-time development environment check and setup for this repo.
set -uo pipefail
cd "$(dirname "$0")/.."

status=0

# Full Xcode is required: widget extension targets cannot be built with
# Command Line Tools alone.
if xcodebuild -version >/dev/null 2>&1; then
    echo "ok    Xcode: $(xcodebuild -version | head -1)"
else
    echo "MISSING  Xcode is not installed or not selected."
    echo "         Install from the App Store, then run:"
    echo "         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "         sudo xcodebuild -license accept"
    status=1
fi

if command -v xcodegen >/dev/null 2>&1; then
    echo "ok    xcodegen: $(xcodegen version 2>/dev/null || echo installed)"
else
    echo "MISSING  xcodegen. Install with: brew install xcodegen"
    status=1
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
    echo "ok    Developer ID Application signing identity present"
else
    echo "note  No Developer ID identity found (only needed for release, Phase 8)"
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    echo "ok    gh authenticated"
else
    echo "note  gh CLI not authenticated (only needed for release, Phase 8)"
fi

if [ "$status" -eq 0 ]; then
    ./scripts/generate.sh
    echo
    echo "Ready. Open Deadlines.xcodeproj or build with:"
    echo "  xcodebuild -scheme Deadlines -destination 'platform=macOS' build"
fi

exit "$status"
