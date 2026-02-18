#!/usr/bin/env bash
#
# Root Structure Validator — ensures only allowed directories exist at repo root.
#
# Usage:
#   bash scripts/validate-root-structure.sh
#   bash scripts/validate-root-structure.sh --help
#
# Exit codes:
#   0 — only allowed directories at root
#   1 — unexpected directories found (CI should fail)
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ─── ALLOWED ROOT ENTRIES ──────────────────────────────────────────────────────
# Directories and files that are permitted at the repository root.
ALLOWED_DIRS=(
  "apparel_platform_backend"
  "apparel_platform_frontend"
  "apparel_platform_postgres"
  ".github"
  ".cursor"
  "scripts"
  "node_modules"
  "coverage"
)

ALLOWED_FILES=(
  "README.md"
  "run-tests.sh"
  ".gitignore"
  ".cursorignore"
  ".DS_Store"
  ".cursorrules"
  "package.json"
  "package-lock.json"
  ".npmrc"
  "tsconfig.json"
)

# ─── FUNCTIONS ─────────────────────────────────────────────────────────────────

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Validates that only allowed directories exist at the repository root."
  echo "Fails with exit code 1 if unexpected directories are found."
  echo ""
  echo "Allowed directories:"
  for d in "${ALLOWED_DIRS[@]}"; do
    echo "  $d/"
  done
  echo ""
  echo "Options:"
  echo "  --help    Show this help message"
}

is_allowed_dir() {
  local name="$1"
  for allowed in "${ALLOWED_DIRS[@]}"; do
    if [ "$name" = "$allowed" ]; then
      return 0
    fi
  done
  return 1
}

is_allowed_file() {
  local name="$1"
  for allowed in "${ALLOWED_FILES[@]}"; do
    if [ "$name" = "$allowed" ]; then
      return 0
    fi
  done
  return 1
}

# ─── ARGUMENT PARSING ──────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --help) usage; exit 0 ;;
  esac
done

# ─── MAIN ──────────────────────────────────────────────────────────────────────

echo "Root Structure Validation"
echo "========================="
echo "Repo root: $REPO_ROOT"
echo ""

UNEXPECTED_DIRS=()
UNEXPECTED_FILES=()

for entry in "$REPO_ROOT"/*; do
  [ -e "$entry" ] || continue
  name="$(basename "$entry")"

  if [ -d "$entry" ]; then
    if ! is_allowed_dir "$name"; then
      UNEXPECTED_DIRS+=("$name")
    fi
  elif [ -f "$entry" ]; then
    if ! is_allowed_file "$name"; then
      UNEXPECTED_FILES+=("$name")
    fi
  fi
done

for entry in "$REPO_ROOT"/.*; do
  [ -e "$entry" ] || continue
  name="$(basename "$entry")"
  [ "$name" = "." ] || [ "$name" = ".." ] || [ "$name" = ".git" ] && continue

  if [ -d "$entry" ]; then
    if ! is_allowed_dir "$name"; then
      UNEXPECTED_DIRS+=("$name")
    fi
  elif [ -f "$entry" ]; then
    if ! is_allowed_file "$name"; then
      UNEXPECTED_FILES+=("$name")
    fi
  fi
done

FAIL=0

if [ ${#UNEXPECTED_DIRS[@]} -gt 0 ]; then
  echo "Unexpected directories at root:"
  for d in "${UNEXPECTED_DIRS[@]}"; do
    echo "  [DIR]  $d/"
  done
  FAIL=1
fi

if [ ${#UNEXPECTED_FILES[@]} -gt 0 ]; then
  echo "Unexpected files at root:"
  for f in "${UNEXPECTED_FILES[@]}"; do
    echo "  [FILE] $f"
  done
  FAIL=1
fi

echo ""

if [ "$FAIL" -eq 1 ]; then
  echo "FAIL: Unexpected entries found at repository root."
  echo "      Move them into apparel_platform_backend/ or apparel_platform_frontend/,"
  echo "      or add them to the allowed list in this script."
  exit 1
else
  echo "PASS: Root structure is clean. Only allowed entries present."
  exit 0
fi
