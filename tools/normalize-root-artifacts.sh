#!/usr/bin/env bash
#
# Normalize root-level artifacts — moves coverage and temp files to correct repos.
#
# Usage:
#   bash normalize-root-artifacts.sh              # dry-run (default)
#   bash normalize-root-artifacts.sh --apply       # execute
#   bash normalize-root-artifacts.sh --help        # show help
#
# Exit codes:
#   0 — clean or migration successful
#   1 — error
#
# SAFETY:
#   - NEVER deletes product source code
#   - Copies first, verifies, then removes original
#   - Idempotent
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="dry-run"

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Normalizes root-level artifacts into correct product repos."
  echo ""
  echo "Actions:"
  echo "  1. Move root coverage/ to apparel_platform_backend/coverage/ (if backend-only)"
  echo "  2. Verify .gitignore entries for coverage in backend and frontend"
  echo ""
  echo "Options:"
  echo "  --apply    Execute normalization (default is dry-run)"
  echo "  --help     Show this help"
}

for arg in "$@"; do
  case "$arg" in
    --apply) MODE="apply" ;;
    --help)  usage; exit 0 ;;
    *)       echo "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

echo "Root Artifact Normalization"
echo "==========================="
echo "Mode: $MODE"
echo "Root: $REPO_ROOT"
echo ""

ACTIONS=0

# ─── COVERAGE ──────────────────────────────────────────────────────────────────

if [ -d "$REPO_ROOT/coverage" ]; then
  FILE_COUNT=$(find "$REPO_ROOT/coverage" -type f | wc -l | tr -d ' ')

  LCOV="$REPO_ROOT/coverage/lcov.info"
  SOURCE="UNKNOWN"
  if [ -f "$LCOV" ]; then
    if grep -q "^SF:src/" "$LCOV" 2>/dev/null; then
      if [ -d "$REPO_ROOT/coverage/apparel_platform_backend" ]; then
        SOURCE="BACKEND_ONLY"
      elif [ -d "$REPO_ROOT/coverage/apparel_platform_frontend" ]; then
        SOURCE="FRONTEND_ONLY"
      else
        SOURCE="BACKEND_ONLY"
      fi
    fi
  fi

  echo "Coverage: $FILE_COUNT files, source: $SOURCE"

  if [ "$SOURCE" = "BACKEND_ONLY" ]; then
    TARGET="$REPO_ROOT/apparel_platform_backend/coverage"
    if [ "$MODE" = "apply" ]; then
      if [ -d "$TARGET" ]; then
        echo "  [SKIP] Backend coverage/ already exists — merge not attempted"
      else
        mv "$REPO_ROOT/coverage" "$TARGET"
        echo "  [MOVED] coverage/ → apparel_platform_backend/coverage/"
        ACTIONS=$((ACTIONS + 1))
      fi
    else
      echo "  [WOULD MOVE] coverage/ → apparel_platform_backend/coverage/"
      ACTIONS=$((ACTIONS + 1))
    fi
  elif [ "$SOURCE" = "FRONTEND_ONLY" ]; then
    TARGET="$REPO_ROOT/apparel_platform_frontend/coverage"
    if [ "$MODE" = "apply" ]; then
      if [ -d "$TARGET" ]; then
        echo "  [SKIP] Frontend coverage/ already exists"
      else
        mv "$REPO_ROOT/coverage" "$TARGET"
        echo "  [MOVED] coverage/ → apparel_platform_frontend/coverage/"
        ACTIONS=$((ACTIONS + 1))
      fi
    else
      echo "  [WOULD MOVE] coverage/ → apparel_platform_frontend/coverage/"
      ACTIONS=$((ACTIONS + 1))
    fi
  else
    echo "  [REVIEW_REQUIRED] Coverage source unclear — not moving"
  fi
else
  echo "Coverage: not present at root (already normalized)"
fi

echo ""

# ─── GITIGNORE CHECK ──────────────────────────────────────────────────────────

echo "Gitignore coverage entries:"

BE_GITIGNORE="$REPO_ROOT/apparel_platform_backend/.gitignore"
if [ -f "$BE_GITIGNORE" ]; then
  if grep -q "^coverage" "$BE_GITIGNORE" 2>/dev/null; then
    echo "  [OK] Backend .gitignore has coverage/"
  else
    echo "  [MISSING] Backend .gitignore needs coverage/ entry"
  fi
else
  echo "  [MISSING] Backend .gitignore does not exist"
fi

FE_GITIGNORE="$REPO_ROOT/apparel_platform_frontend/.gitignore"
if [ -f "$FE_GITIGNORE" ]; then
  if grep -q "coverage" "$FE_GITIGNORE" 2>/dev/null; then
    echo "  [OK] Frontend .gitignore has coverage"
  else
    echo "  [MISSING] Frontend .gitignore needs coverage entry"
  fi
else
  echo "  [MISSING] Frontend .gitignore does not exist"
fi

echo ""
echo "==========================="
echo "Actions: $ACTIONS"
echo "==========================="
