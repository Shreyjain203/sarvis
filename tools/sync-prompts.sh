#!/usr/bin/env bash
# sync-prompts.sh — Copy editable prompts/*.md into the app bundle resource folder.
# Run this after editing any file in prompts/ to keep the bundle copy in sync.
# Usage: ./tools/sync-prompts.sh  (run from repo root)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SRC="${REPO_ROOT}/prompts"
DST="${REPO_ROOT}/Sarvis/Resources/Prompts"

mkdir -p "${DST}"
cp "${SRC}"/*.md "${DST}/"

echo "Synced $(ls "${SRC}"/*.md | wc -l | tr -d ' ') prompt(s) → ${DST}"
