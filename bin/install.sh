#!/usr/bin/env bash
#
# ship-kit universal installer
#
# Copies ship-kit's skills into a target agent's skills directory. ship-kit's skills
# follow the open Agent Skills standard (SKILL.md), so they run on any harness that reads
# that format: Claude Code, OpenAI Codex, xAI Grok, Nous Hermes, OpenClaw, VS Code /
# Copilot, and anything else that scans a skills directory.
#
# Usage:
#   bin/install.sh <target> [options]
#
# Targets:
#   agents      ~/.agents/skills            (open standard — widest reach: Codex, Grok community, OpenClaw, VS Code)
#   claude      ~/.claude/skills            (Claude Code, personal scope)
#   codex       ~/.agents/skills            (alias of 'agents' — Codex scans .agents/skills)
#   vscode      ~/.agents/skills            (alias of 'agents' — VS Code scans .agents/skills)
#   grok        ~/.grok/skills             (xAI Grok Build, official)
#   hermes      ~/.hermes/skills/ship-kit   (Nous Hermes — category-nested)
#   openclaw    ~/.openclaw/skills          (OpenClaw managed skills)
#   copilot     ~/.copilot/skills           (GitHub Copilot / VS Code, user scope)
#   all         every target whose home dir already exists (auto-detected)
#
# Options:
#   --project        install into ./.agents/skills in the CURRENT repo instead of user scope
#   --dest <dir>     install into an arbitrary skills directory
#   --link           symlink instead of copy (for local development)
#   --list           list bundled skills and exit
#   -h, --help       show this help
#
set -euo pipefail

# Resolve the kit's skills dir relative to this script (works from a clone, anywhere).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$KIT_ROOT/.agents/skills"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }

[ -d "$SRC" ] || die "skills source not found at $SRC — run this from a ship-kit checkout"

usage() { sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//; s/^#//; /^set -euo/d'; }

list_skills() {
  echo "Bundled skills:"
  for d in "$SRC"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    printf '  - %s\n' "$name"
  done
}

LINK=0
PROJECT=0
DEST=""
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --link) LINK=1 ;;
    --project) PROJECT=1 ;;
    --dest) shift; DEST="${1:-}"; [ -n "$DEST" ] || die "--dest needs a directory" ;;
    --list) list_skills; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [ -z "$TARGET" ] || die "only one target allowed (got '$TARGET' and '$1')"; TARGET="$1" ;;
  esac
  shift
done

# Harness table: <canonical-name>:<home-subdir>:<skills-subpath>. target_dir, target_home,
# and the detection / `all` loops all read from this — add a harness by adding one row (and
# an alias below if it needs one). Kept as a function for bash 3.2 (macOS) compatibility.
harness_table() {
  cat <<'EOF'
agents:.agents:skills
claude:.claude:skills
grok:.grok:skills
hermes:.hermes:skills/ship-kit
openclaw:.openclaw:skills
copilot:.copilot:skills
EOF
}

# Resolve an alias to its canonical harness name.
canonical() {
  case "$1" in
    codex|vscode) echo agents ;;
    grok-build)   echo grok ;;
    *)            echo "$1" ;;
  esac
}

canonical_targets() { harness_table | cut -d: -f1; }

# Print a target's skills dir (kind=dir) or detection home (kind=home); return 1 if unknown.
target_path() {
  local kind="$2" key name home skills
  key="$(canonical "$1")"
  while IFS=: read -r name home skills; do
    [ "$name" = "$key" ] || continue
    [ "$kind" = home ] && echo "$HOME/$home" || echo "$HOME/$home/$skills"
    return 0
  done <<EOF
$(harness_table)
EOF
  return 1
}
target_dir()  { target_path "$1" dir; }
target_home() { target_path "$1" home; }

install_to() {
  dest="$1"
  mkdir -p "$dest"
  # Refuse to install into our own source tree: the per-skill `rm -rf` below would delete the
  # canonical .agents/skills before copying it (e.g. `--project` / `--dest $repo/.agents/skills`
  # run from a ship-kit checkout, where dest resolves to $SRC). Compare physical paths.
  local real_dest; real_dest="$(cd "$dest" && pwd)"
  case "$real_dest/" in
    "$SRC"/*) die "refusing to install into ship-kit's own source skills dir ($real_dest) — pick a different target or --dest" ;;
  esac
  for d in "$SRC"/*/; do
    [ -d "$d" ] || continue          # no-match glob (empty source) → nothing to do
    name="$(basename "$d")"
    src="${d%/}"
    rm -rf "${dest:?}/${name:?}"
    if [ "$LINK" -eq 1 ]; then
      ln -s "$src" "$dest/$name" || die "symlink failed: $src → $dest/$name"
    else
      cp -R "$src" "$dest/$name" || die "copy failed: $src → $dest/$name"
    fi
    info "$name → $dest/$name"
  done
}

# --- dispatch -------------------------------------------------------------

if [ -n "$DEST" ]; then
  echo "Installing ship-kit skills → $DEST"
  install_to "$DEST"
  echo "Done."
  exit 0
fi

if [ "$PROJECT" -eq 1 ]; then
  dest="$PWD/.agents/skills"
  echo "Installing ship-kit skills into this repo → $dest"
  install_to "$dest"
  echo "Done. Agents that scan .agents/skills (Codex, Grok, OpenClaw, VS Code) will discover them here."
  exit 0
fi

if [ -z "$TARGET" ]; then
  usage
  echo
  echo "Detected harness homes:"
  for t in $(canonical_targets); do
    h="$(target_home "$t")"
    [ -n "${h:-}" ] && [ -d "$h" ] && printf '  ✓ %-9s (%s)\n' "$t" "$h"
  done
  echo
  echo "Pick a target, or run:  bin/install.sh all"
  exit 0
fi

if [ "$TARGET" = "all" ]; then
  installed=0
  for t in $(canonical_targets); do
    h="$(target_home "$t")"
    if [ -n "${h:-}" ] && [ -d "$h" ]; then
      dest="$(target_dir "$t")"
      echo "Installing → $t ($dest)"
      install_to "$dest"
      installed=$((installed+1))
    fi
  done
  [ "$installed" -gt 0 ] || die "no known harness homes found under \$HOME — install one, or use --dest / --project"
  echo "Done. Installed into $installed harness(es)."
  exit 0
fi

dest="$(target_dir "$TARGET")" || die "unknown target: $TARGET (try: $(canonical_targets | tr '\n' ' ')all, or aliases codex/vscode/grok-build)"
echo "Installing ship-kit skills → $TARGET ($dest)"
install_to "$dest"
echo "Done."
