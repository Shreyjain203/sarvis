#!/usr/bin/env bash
# Generate the Xcode project from project.yml and open it.
# Re-run this any time you add files or change project.yml.
set -e

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "→ Installing xcodegen via Homebrew..."
    brew install xcodegen
  else
    echo "Homebrew not found. Install Homebrew first: https://brew.sh"
    exit 1
  fi
fi

ACTIVE="$(xcode-select -p 2>/dev/null || true)"
case "$ACTIVE" in
  *Xcode.app*) ;;
  *)
    if [ -d "/Applications/Xcode.app" ]; then
      echo "→ Pointing xcode-select at /Applications/Xcode.app (sudo required)..."
      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    else
      echo "Xcode.app not found in /Applications. Install Xcode from the App Store."
      exit 1
    fi
    ;;
esac

echo "→ Generating Xcode project..."
xcodegen generate

echo "→ Done. Opening Sarvis.xcodeproj..."
open Sarvis.xcodeproj
