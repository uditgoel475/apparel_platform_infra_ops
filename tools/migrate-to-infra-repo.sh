#!/usr/bin/env bash
#
# Migrate infra/ops files from monorepo root into infra_ops_repo_staging.
#
# Usage:
#   bash scripts/migrate-to-infra-repo.sh              # dry-run (default)
#   bash scripts/migrate-to-infra-repo.sh --apply       # copy + verify + remove originals
#   bash scripts/migrate-to-infra-repo.sh --help        # show help
#
# Exit codes:
#   0 — migration successful (or dry-run clean)
#   1 — checksum mismatch or safety violation
#
# SAFETY GUARANTEES:
#   - Copies FIRST, verifies checksums, THEN removes originals
#   - NEVER touches apparel_platform_backend/src, apparel_platform_frontend/src,
#     apparel_platform_postgres/, node_modules, .env, prisma, docker volumes
#   - Idempotent: safe to run multiple times
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$REPO_ROOT/infra_ops_repo_staging"
MODE="dry-run"

# ─── PROTECTED PATHS (NEVER TOUCH) ────────────────────────────────────────────
PROTECTED=(
  "apparel_platform_backend/src"
  "apparel_platform_frontend/src"
  "apparel_platform_postgres"
  "node_modules"
  ".env"
  "prisma"
)

# ─── MIGRATION MAP ────────────────────────────────────────────────────────────
# Format: "source_relative_path|destination_relative_path_in_staging"
MIGRATE_FILES=(
  "scripts/repo-health-check.sh|scripts/repo-health-check.sh"
  "scripts/runtime-safety-check.sh|scripts/runtime-safety-check.sh"
  "scripts/safe-root-cleanup.sh|scripts/safe-root-cleanup.sh"
  "scripts/validate-root-structure.sh|scripts/validate-root-structure.sh"
  "SYSTEM_BRAIN_EXPORT_FULL.md|brain_exports/SYSTEM_BRAIN_EXPORT_FULL.md"
  "run-tests.sh|tools/run-tests.sh"
  "README.md|README_PLATFORM_ORIGINAL.md"
  ".github/workflows/validate-docs.yml|ci/validate-docs.yml.reference"
)

# ─── FUNCTIONS ─────────────────────────────────────────────────────────────────

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Migrates infra/ops files from monorepo root to infra_ops_repo_staging/"
  echo ""
  echo "Options:"
  echo "  --apply    Execute migration (default is dry-run)"
  echo "  --help     Show this help"
  echo ""
  echo "Files migrated:"
  for entry in "${MIGRATE_FILES[@]}"; do
    src="${entry%%|*}"
    dst="${entry##*|}"
    echo "  $src → infra_ops_repo_staging/$dst"
  done
}

safety_check() {
  local path="$1"
  for p in "${PROTECTED[@]}"; do
    if [[ "$path" == *"$p"* ]]; then
      echo "SAFETY VIOLATION: '$path' matches protected pattern '$p'. Aborting."
      exit 1
    fi
  done
}

verify_checksum() {
  local src="$1"
  local dst="$2"
  local src_sum dst_sum
  src_sum=$(shasum -a 256 "$src" 2>/dev/null | cut -d' ' -f1)
  dst_sum=$(shasum -a 256 "$dst" 2>/dev/null | cut -d' ' -f1)
  if [ "$src_sum" != "$dst_sum" ]; then
    echo "CHECKSUM MISMATCH:"
    echo "  Source: $src ($src_sum)"
    echo "  Dest:   $dst ($dst_sum)"
    return 1
  fi
  return 0
}

# ─── ARGUMENT PARSING ──────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --apply) MODE="apply" ;;
    --help)  usage; exit 0 ;;
    *)       echo "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

# ─── MAIN ──────────────────────────────────────────────────────────────────────

echo "Infra/Ops Migration"
echo "==================="
echo "Mode:    $MODE"
echo "Source:  $REPO_ROOT"
echo "Target:  $STAGING"
echo ""

COPIED=0
VERIFIED=0
REMOVED=0
SKIPPED=0
ERRORS=0

for entry in "${MIGRATE_FILES[@]}"; do
  SRC_REL="${entry%%|*}"
  DST_REL="${entry##*|}"
  SRC_ABS="$REPO_ROOT/$SRC_REL"
  DST_ABS="$STAGING/$DST_REL"

  if [ ! -f "$SRC_ABS" ]; then
    echo "  [SKIP] $SRC_REL (not found — already migrated?)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  safety_check "$SRC_REL"

  if [ "$MODE" = "dry-run" ]; then
    SIZE=$(wc -c < "$SRC_ABS" | tr -d ' ')
    echo "  [WOULD MIGRATE] $SRC_REL → $DST_REL ($SIZE bytes)"
    COPIED=$((COPIED + 1))
  else
    DST_DIR="$(dirname "$DST_ABS")"
    mkdir -p "$DST_DIR"

    cp "$SRC_ABS" "$DST_ABS"
    COPIED=$((COPIED + 1))

    if verify_checksum "$SRC_ABS" "$DST_ABS"; then
      VERIFIED=$((VERIFIED + 1))
      echo "  [MIGRATED] $SRC_REL → $DST_REL (checksum OK)"
    else
      echo "  [ERROR] Checksum mismatch for $SRC_REL — original NOT removed"
      ERRORS=$((ERRORS + 1))
      continue
    fi

    # This script is part of scripts/ — don't remove self during execution
    if [ "$SRC_REL" = "scripts/migrate-to-infra-repo.sh" ]; then
      echo "  [KEEP] $SRC_REL (self — remove manually after migration)"
      continue
    fi

    rm "$SRC_ABS"
    REMOVED=$((REMOVED + 1))
  fi
done

echo ""
echo "─────────────────────────────────────"
if [ "$MODE" = "dry-run" ]; then
  echo "Dry-run: $COPIED file(s) would be migrated, $SKIPPED skipped"
  echo ""
  echo "Run with --apply to execute:"
  echo "  bash scripts/migrate-to-infra-repo.sh --apply"
else
  echo "Copied:   $COPIED"
  echo "Verified: $VERIFIED"
  echo "Removed:  $REMOVED"
  echo "Skipped:  $SKIPPED"
  echo "Errors:   $ERRORS"

  if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "FAIL: $ERRORS error(s) during migration."
    exit 1
  fi

  # Clean up empty scripts/ if all files moved
  if [ -d "$REPO_ROOT/scripts" ]; then
    REMAINING=$(find "$REPO_ROOT/scripts" -type f | wc -l | tr -d ' ')
    if [ "$REMAINING" -eq 0 ]; then
      rmdir "$REPO_ROOT/scripts" 2>/dev/null || true
      echo "Removed empty scripts/ directory"
    else
      echo "scripts/ still has $REMAINING file(s) — not removed"
    fi
  fi

  # Clean up empty .github/workflows/ if empty
  if [ -d "$REPO_ROOT/.github/workflows" ]; then
    REMAINING=$(find "$REPO_ROOT/.github/workflows" -type f | wc -l | tr -d ' ')
    if [ "$REMAINING" -eq 0 ]; then
      rm -rf "$REPO_ROOT/.github" 2>/dev/null || true
      echo "Removed empty .github/ directory"
    fi
  fi
fi
echo "─────────────────────────────────────"

exit 0
