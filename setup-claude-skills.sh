#!/usr/bin/env bash
#
# setup-claude-skills.sh
#
# Installs the Flutter Claude Toolkit skill suite into the current Flutter project.
#
# Usage:
#   ./setup-claude-skills.sh                # interactive install
#   ./setup-claude-skills.sh --upgrade      # upgrade existing skills, preserve project CLAUDE.md
#   ./setup-claude-skills.sh --dry-run      # show what would happen, change nothing
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(pwd)"
DRY_RUN=false
UPGRADE_MODE=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --upgrade) UPGRADE_MODE=true ;;
    --help|-h)
      cat <<'EOF'
Usage: setup-claude-skills.sh [--upgrade] [--dry-run]

  --upgrade    Update skills, keep your project's CLAUDE.md intact.
  --dry-run    Show what would change without modifying anything.
  --help       Show this help.
EOF
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

say() { printf '\033[1;34m[claude-skills]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[claude-skills]\033[0m %s\n' "$1" >&2; }
ok() { printf '\033[1;32m[claude-skills]\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31m[claude-skills]\033[0m %s\n' "$1" >&2; exit 1; }

# Sanity checks
if [ ! -f "${TARGET_DIR}/pubspec.yaml" ]; then
  fail "No pubspec.yaml in current directory. Run this from your Flutter project root."
fi

if ! grep -q "flutter:" "${TARGET_DIR}/pubspec.yaml"; then
  warn "pubspec.yaml exists but doesn't mention 'flutter:'. Continue anyway? (y/N)"
  read -r confirm
  [ "$confirm" = "y" ] || fail "Aborted."
fi

if [ ! -d "${SCRIPT_DIR}/.claude/skills" ]; then
  fail "Skills folder not found at ${SCRIPT_DIR}/.claude/skills. Are you running this from the toolkit repo?"
fi

PROJECT_NAME="$(basename "${TARGET_DIR}")"
say "Installing into project: ${PROJECT_NAME}"
say "Target directory: ${TARGET_DIR}"

if [ "$DRY_RUN" = true ]; then
  warn "DRY RUN — no changes will be made."
fi

# What will be copied
SKILLS_TO_INSTALL=()
for skill in "${SCRIPT_DIR}/.claude/skills"/*/; do
  SKILLS_TO_INSTALL+=("$(basename "${skill}")")
done

say "Skills available to install:"
for skill in "${SKILLS_TO_INSTALL[@]}"; do
  printf '  - %s\n' "$skill"
done

# Backup existing setup
BACKUP_DIR=""
if [ -d "${TARGET_DIR}/.claude" ] || [ -f "${TARGET_DIR}/CLAUDE.md" ]; then
  if [ "$UPGRADE_MODE" = false ]; then
    warn "Existing .claude/ or CLAUDE.md found in target."
    warn "Recommended: backup before continuing. Make backup? (Y/n)"
    read -r confirm
    if [ "${confirm:-y}" != "n" ]; then
      BACKUP_DIR="${TARGET_DIR}/.claude-backup-$(date +%Y%m%d-%H%M%S)"
      if [ "$DRY_RUN" = true ]; then
        say "[dry-run] Would backup existing to ${BACKUP_DIR}"
      else
        mkdir -p "${BACKUP_DIR}"
        [ -d "${TARGET_DIR}/.claude" ] && cp -r "${TARGET_DIR}/.claude" "${BACKUP_DIR}/"
        [ -f "${TARGET_DIR}/CLAUDE.md" ] && cp "${TARGET_DIR}/CLAUDE.md" "${BACKUP_DIR}/"
        ok "Backup saved to ${BACKUP_DIR}"
      fi
    fi
  fi
fi

# Install skills
say "Installing skills into .claude/skills/..."
if [ "$DRY_RUN" = false ]; then
  mkdir -p "${TARGET_DIR}/.claude/skills"
fi

for skill in "${SKILLS_TO_INSTALL[@]}"; do
  SRC="${SCRIPT_DIR}/.claude/skills/${skill}"
  DST="${TARGET_DIR}/.claude/skills/${skill}"
  if [ -d "$DST" ] && [ "$UPGRADE_MODE" = false ]; then
    warn "Skill '${skill}' already exists. Overwrite? (y/N)"
    read -r confirm
    [ "$confirm" = "y" ] || continue
  fi
  if [ "$DRY_RUN" = true ]; then
    printf '  [dry-run] Would copy: %s -> %s\n' "$SRC" "$DST"
  else
    rm -rf "$DST"
    cp -r "$SRC" "$DST"
    printf '  ✓ %s\n' "$skill"
  fi
done

# CLAUDE.md handling
TEMPLATE_PATH="${SCRIPT_DIR}/templates/CLAUDE.md.template"
PROJECT_CLAUDE="${TARGET_DIR}/CLAUDE.md"

if [ "$UPGRADE_MODE" = true ]; then
  say "Upgrade mode — preserving existing CLAUDE.md."
elif [ -f "${PROJECT_CLAUDE}" ]; then
  EXISTING_SIZE=$(wc -c < "${PROJECT_CLAUDE}" | tr -d ' ')
  if [ "${EXISTING_SIZE}" -gt 100 ]; then
    warn "CLAUDE.md exists (${EXISTING_SIZE} bytes). Replace with template? (y/N)"
    read -r confirm
    if [ "$confirm" = "y" ]; then
      if [ "$DRY_RUN" = false ]; then
        cp "${TEMPLATE_PATH}" "${PROJECT_CLAUDE}"
        ok "CLAUDE.md replaced with template — fill in <<FILL IN>> markers."
      fi
    else
      say "Keeping existing CLAUDE.md."
    fi
  else
    if [ "$DRY_RUN" = false ]; then
      cp "${TEMPLATE_PATH}" "${PROJECT_CLAUDE}"
      ok "Empty CLAUDE.md replaced with template."
    fi
  fi
else
  if [ "$DRY_RUN" = false ]; then
    cp "${TEMPLATE_PATH}" "${PROJECT_CLAUDE}"
    ok "CLAUDE.md created from template — fill in <<FILL IN>> markers."
  else
    say "[dry-run] Would create CLAUDE.md from template."
  fi
fi

# Add to .gitignore (only if missing entries)
GITIGNORE="${TARGET_DIR}/.gitignore"
ENTRIES_TO_ADD=(".claude-backup-*/" ".DS_Store" "**/.DS_Store")
if [ -f "${GITIGNORE}" ]; then
  for entry in "${ENTRIES_TO_ADD[@]}"; do
    if ! grep -qF "$entry" "${GITIGNORE}"; then
      if [ "$DRY_RUN" = false ]; then
        printf '\n%s\n' "$entry" >> "${GITIGNORE}"
      fi
    fi
  done
fi

# Done
ok ""
ok "═══════════════════════════════════════════════════"
ok "Flutter Claude Toolkit installed."
ok "═══════════════════════════════════════════════════"
ok ""
say "Next steps:"
printf '  1. Open CLAUDE.md and fill in the <<FILL IN>> markers\n'
printf '  2. Optional: customize skills under .claude/skills/<skill>/ if your project conventions differ\n'
printf '  3. Restart Claude Code in this project — skills auto-load\n'
printf '\n'
say "To upgrade later: re-run this script with --upgrade flag."
