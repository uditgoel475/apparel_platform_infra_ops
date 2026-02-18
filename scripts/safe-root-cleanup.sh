#!/usr/bin/env bash
#
# Safe Root Cleanup — removes known legacy directories after repo consolidation.
#
# Usage:
#   bash scripts/safe-root-cleanup.sh            # dry-run (default)
#   bash scripts/safe-root-cleanup.sh --apply     # actually delete
#   bash scripts/safe-root-cleanup.sh --help      # show help
#
# Exit codes:
#   0 — clean (nothing to remove, or removal successful)
#   1 — error or safety violation
#
# SAFETY GUARANTEES:
#   - NEVER deletes docker volumes, postgres data, docker-compose files, .env files
#   - NEVER deletes apparel_platform_backend, apparel_platform_frontend, apparel_platform_postgres
#   - NEVER runs docker prune, volume prune, or any destructive docker command
#   - Only removes explicitly listed legacy directories
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="dry-run"

# ─── SAFE REMOVABLE LIST ───────────────────────────────────────────────────────
# These are the ONLY directories this script will ever consider deleting.
# Each entry is a path relative to REPO_ROOT.
SAFE_REMOVABLE=(
  "platform"
  "ops"
  "coverage"
  "tmp"
  ".cursor/tmp"
)

# ─── NEVER DELETE LIST ─────────────────────────────────────────────────────────
# Hardcoded safety: if any of these appear in a delete path, abort immediately.
PROTECTED_PATTERNS=(
  "apparel_platform_backend"
  "apparel_platform_frontend"
  "apparel_platform_postgres"
  "docker-compose"
  ".env"
  "node_modules"
  "prisma"
  "docker"
  "volumes"
  "pgdata"
  "postgres-data"
)

# ─── FUNCTIONS ─────────────────────────────────────────────────────────────────

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --apply    Actually delete legacy folders (default is dry-run)"
  echo "  --help     Show this help message"
  echo ""
  echo "Safe removable directories:"
  for dir in "${SAFE_REMOVABLE[@]}"; do
    echo "  $dir/"
  done
  echo ""
  echo "Protected (NEVER deleted):"
  echo "  apparel_platform_backend/"
  echo "  apparel_platform_frontend/"
  echo "  apparel_platform_postgres/"
  echo "  Any docker volumes, .env files, postgres data, docker-compose files"
}

safety_check() {
  local target="$1"
  for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$target" == *"$pattern"* ]]; then
      echo "SAFETY VIOLATION: '$target' matches protected pattern '$pattern'. Aborting."
      exit 1
    fi
  done
}

# ─── ARGUMENT PARSING ──────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --apply)  MODE="apply" ;;
    --help)   usage; exit 0 ;;
    *)        echo "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

# ─── MAIN ──────────────────────────────────────────────────────────────────────

echo "Safe Root Cleanup"
echo "================="
echo "Mode:      $MODE"
echo "Repo root: $REPO_ROOT"
echo ""

FOUND=0
REMOVED=0

for dir in "${SAFE_REMOVABLE[@]}"; do
  TARGET="$REPO_ROOT/$dir"
  if [ -e "$TARGET" ]; then
    FOUND=$((FOUND + 1))
    safety_check "$dir"

    if [ "$MODE" = "apply" ]; then
      echo "  [DELETE] $dir/"
      rm -rf "$TARGET"
      REMOVED=$((REMOVED + 1))
    else
      SIZE=$(du -sh "$TARGET" 2>/dev/null | cut -f1 || echo "?")
      COUNT=$(find "$TARGET" -type f 2>/dev/null | wc -l | tr -d ' ')
      echo "  [WOULD DELETE] $dir/  ($COUNT files, $SIZE)"
    fi
  fi
done

echo ""
echo "─────────────────────────────"
if [ "$MODE" = "apply" ]; then
  echo "Removed: $REMOVED directory(ies)"
else
  echo "Found: $FOUND removable directory(ies)"
  if [ "$FOUND" -gt 0 ]; then
    echo ""
    echo "Run with --apply to delete:"
    echo "  bash scripts/safe-root-cleanup.sh --apply"
  fi
fi
echo "─────────────────────────────"

exit 0
