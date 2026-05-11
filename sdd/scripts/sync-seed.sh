#!/usr/bin/env bash
# Sync the sdd/ seed bundle for the /sdd-setup skill.
#
# /sdd-setup carries a seed copy of the user-facing sdd/ files so a brand-new
# project can bootstrap from the skill alone. Whenever a file under
# sdd/templates/, sdd/trackers/, or the top-level sdd/ scaffold (config.example.json,
# README.md, prd-template*.md) changes, run this script to keep the seed in sync.
#
# Idempotent. Safe to run any number of times.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SDD_DIR="$REPO_ROOT/sdd"
SEED_DIR="$REPO_ROOT/.claude/skills/sdd-setup/references/seed"

if [[ ! -d "$SDD_DIR" ]]; then
  echo "error: $SDD_DIR not found — run from a repo with sdd/ initialised." >&2
  exit 1
fi

if [[ ! -d "$SEED_DIR" ]]; then
  echo "error: $SEED_DIR not found — sdd-setup skill not present?" >&2
  exit 1
fi

# Top-level files
TOP_LEVEL=(
  "README.md"
  "config.example.json"
  "prd-template.md"
  "prd-template-mini.md"
)

for f in "${TOP_LEVEL[@]}"; do
  src="$SDD_DIR/$f"
  dst="$SEED_DIR/$f"
  if [[ -f "$src" ]]; then
    cp "$src" "$dst"
    echo "  synced  $f"
  else
    echo "  skipped $f (source missing)"
  fi
done

# Tracker recipes
mkdir -p "$SEED_DIR/trackers"
for src in "$SDD_DIR"/trackers/*.md; do
  [[ -f "$src" ]] || continue
  cp "$src" "$SEED_DIR/trackers/"
  echo "  synced  trackers/$(basename "$src")"
done

# Shared templates
mkdir -p "$SEED_DIR/templates"
for src in "$SDD_DIR"/templates/*.md; do
  [[ -f "$src" ]] || continue
  cp "$src" "$SEED_DIR/templates/"
  echo "  synced  templates/$(basename "$src")"
done

echo "done. seed bundle at $SEED_DIR is up to date."
