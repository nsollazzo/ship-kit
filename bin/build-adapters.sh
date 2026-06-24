#!/usr/bin/env bash
#
# Generate harness-specific skill trees from the canonical source.
#
# Canonical source of truth:  .agents/skills/<name>/SKILL.md   (open Agent Skills standard).
# Most harnesses read that directly (Claude via the plugin "source", Codex / Grok community /
# OpenClaw / VS Code by scanning .agents/skills). Nous Hermes is the exception: its "Tap"
# distribution (`hermes skills tap add <owner>/<repo>`) scans a FLAT `skills/<name>/SKILL.md`
# tree at the repo root (verified against hermes-agent's skills_hub.py — depth-1, dir name is
# the install slug, NOT category-nested). So we generate that tree here.
#
# Run this after editing any canonical skill, and commit the result (the Tap fetches it from
# GitHub's default branch). It is a pure copy — Hermes loads the same name/description/license
# frontmatter, so no transform is needed.
#
# Usage:  bin/build-adapters.sh [--check]
#   --check   verify the generated tree is in sync with canonical; exit 1 if not (for CI).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$KIT_ROOT/.agents/skills"
HERMES_TAP="$KIT_ROOT/skills"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
[ -d "$SRC" ] || die "canonical skills not found at $SRC"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

build_tap_tree() {
  local dest="$1"
  rm -rf "${dest:?}"
  mkdir -p "$dest"
  cp -R "$SRC"/. "$dest/"   # copy every skill dir in one call (the /. copies contents)
}

write_grouping() {
  # skills.sh.json gives the Hermes Skills Hub a human-readable category label.
  local dest="$1"
  local names
  names="$(for d in "$SRC"/*/; do [ -d "$d" ] || continue; printf '"%s",' "$(basename "$d")"; done)"
  names="${names%,}"
  printf '{\n  "groupings": [\n    { "title": "ship-kit", "skills": [%s] }\n  ]\n}\n' "$names" \
    > "$dest/skills.sh.json"
}

generate() {
  build_tap_tree "$1"
  write_grouping "$1"
}

if [ "$CHECK" -eq 1 ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  generate "$TMP/skills"
  if ! drift="$(diff -rq "$TMP/skills" "$HERMES_TAP" 2>&1)"; then
    printf '%s\n' "$drift" >&2
    die "generated Hermes tap tree (skills/) is out of sync with .agents/skills (see above) — run bin/build-adapters.sh"
  fi
  echo "skills/ is in sync with .agents/skills/"
  exit 0
fi

echo "Generating Hermes tap tree: skills/ ← .agents/skills/"
generate "$HERMES_TAP"
n=$(find "$HERMES_TAP" -name SKILL.md | wc -l | tr -d ' ')
echo "Wrote $n skills to skills/ (+ skills.sh.json). Commit them so 'hermes skills tap add' can fetch them."
