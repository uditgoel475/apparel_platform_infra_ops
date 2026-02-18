#!/usr/bin/env bash
#
# Master Repo Health Check — runs all validation steps in sequence.
#
# Usage:
#   bash scripts/repo-health-check.sh               # structure + runtime + docs
#   bash scripts/repo-health-check.sh --cleanup      # also run safe cleanup (dry-run)
#   bash scripts/repo-health-check.sh --cleanup-apply # also run safe cleanup (apply)
#   bash scripts/repo-health-check.sh --help          # show help
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
#
# Step order:
#   1. Root structure validation
#   2. Runtime safety check
#   3. Documentation validation
#   4. Optional cleanup (if --cleanup or --cleanup-apply)
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
CLEANUP_MODE=""
OVERALL_EXIT=0

# ─── FUNCTIONS ─────────────────────────────────────────────────────────────────

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Master health check that runs all validation steps."
  echo ""
  echo "Steps:"
  echo "  1. Root structure validation  (scripts/validate-root-structure.sh)"
  echo "  2. Runtime safety check       (scripts/runtime-safety-check.sh)"
  echo "  3. Documentation validation   (apparel_platform_backend/scripts/validate-doc-structure.sh)"
  echo "  4. Cleanup (optional)         (scripts/safe-root-cleanup.sh)"
  echo ""
  echo "Options:"
  echo "  --cleanup        Run cleanup in dry-run mode after checks"
  echo "  --cleanup-apply  Run cleanup in apply mode after checks"
  echo "  --help           Show this help message"
}

separator() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

run_step() {
  local step_num="$1"
  local step_name="$2"
  local script_path="$3"
  shift 3
  local args=("$@")

  echo "STEP $step_num: $step_name"
  echo "────────────────────────────────────"

  if [ ! -f "$script_path" ]; then
    echo "  [SKIP] Script not found: $script_path"
    return 0
  fi

  if bash "$script_path" "${args[@]}" 2>&1; then
    echo ""
    echo "  Result: PASSED"
  else
    local exit_code=$?
    echo ""
    echo "  Result: FAILED (exit code $exit_code)"
    OVERALL_EXIT=1
  fi
}

# ─── ARGUMENT PARSING ──────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --cleanup)       CLEANUP_MODE="dry-run" ;;
    --cleanup-apply) CLEANUP_MODE="apply" ;;
    --help)          usage; exit 0 ;;
    *)               echo "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

# ─── MAIN ──────────────────────────────────────────────────────────────────────

echo ""
echo "  REPO HEALTH CHECK"
echo "  ================="
echo "  Repo: $REPO_ROOT"
echo "  Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

separator

# Step 1: Root Structure
run_step 1 "Root Structure Validation" \
  "$SCRIPTS_DIR/validate-root-structure.sh"

separator

# Step 2: Runtime Safety
run_step 2 "Runtime Safety Check" \
  "$SCRIPTS_DIR/runtime-safety-check.sh"

separator

# Step 3: Documentation Validation
run_step 3 "Documentation Validation" \
  "$REPO_ROOT/apparel_platform_backend/scripts/validate-doc-structure.sh"

# Step 4: Cleanup (optional)
if [ -n "$CLEANUP_MODE" ]; then
  separator

  if [ "$CLEANUP_MODE" = "apply" ]; then
    run_step 4 "Safe Root Cleanup (APPLY)" \
      "$SCRIPTS_DIR/safe-root-cleanup.sh" "--apply"
  else
    run_step 4 "Safe Root Cleanup (dry-run)" \
      "$SCRIPTS_DIR/safe-root-cleanup.sh"
  fi
fi

separator

echo "OVERALL RESULT"
echo "────────────────────────────────────"

if [ "$OVERALL_EXIT" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "SOME CHECKS FAILED — review output above"
fi

echo ""
exit "$OVERALL_EXIT"
