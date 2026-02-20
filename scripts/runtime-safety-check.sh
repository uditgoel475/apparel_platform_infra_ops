#!/usr/bin/env bash
#
# Runtime Safety Check — read-only verification of infrastructure state.
#
# Usage:
#   bash scripts/runtime-safety-check.sh
#   bash scripts/runtime-safety-check.sh --help
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
#
# SAFETY GUARANTEES:
#   - This script NEVER modifies infrastructure
#   - No docker run/stop/prune/rm commands
#   - No database writes
#   - No file modifications
#   - Read-only checks only
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_ROOT="$REPO_ROOT/apparel_platform_backend"
ENV_FILE="$BACKEND_ROOT/.env"

PASS=0
FAIL=0
WARN=0

# ─── FUNCTIONS ─────────────────────────────────────────────────────────────────

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Read-only infrastructure health checks. NEVER modifies anything."
  echo ""
  echo "Checks:"
  echo "  1. Docker daemon running"
  echo "  2. Postgres container exists"
  echo "  3. Unleash container exists (if docker-compose present)"
  echo "  4. Required env variables in backend .env"
  echo "  5. Backend feature-flags endpoint reachable"
  echo ""
  echo "Options:"
  echo "  --help    Show this help message"
}

check_pass() {
  echo "  [PASS] $1"
  PASS=$((PASS + 1))
}

check_fail() {
  echo "  [FAIL] $1"
  FAIL=$((FAIL + 1))
}

check_warn() {
  echo "  [WARN] $1"
  WARN=$((WARN + 1))
}

# ─── ARGUMENT PARSING ──────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --help) usage; exit 0 ;;
  esac
done

# ─── MAIN ──────────────────────────────────────────────────────────────────────

echo "Runtime Safety Check"
echo "===================="
echo "Repo root: $REPO_ROOT"
echo ""

# ─── CHECK 1: DOCKER DAEMON ───────────────────────────────────────────────────

echo "1. Docker Daemon"

if command -v docker &>/dev/null; then
  if docker info &>/dev/null; then
    check_pass "Docker daemon is running"
  else
    check_warn "Docker is installed but daemon is not running — container checks will be skipped"
  fi
else
  check_warn "Docker is not installed — container checks will be skipped"
fi

echo ""

# ─── CHECK 2: POSTGRES CONTAINER ──────────────────────────────────────────────

echo "2. Postgres Container"

if command -v docker &>/dev/null && docker info &>/dev/null; then
  PG_CONTAINERS=$(docker ps --filter "name=postgres" --filter "name=pg" --filter "name=db" --format "{{.Names}} ({{.Status}})" 2>/dev/null || true)
  if [ -n "$PG_CONTAINERS" ]; then
    check_pass "Postgres container(s) found:"
    echo "$PG_CONTAINERS" | while read -r line; do
      echo "         $line"
    done
  else
    PG_STOPPED=$(docker ps -a --filter "name=postgres" --filter "name=pg" --filter "name=db" --format "{{.Names}} ({{.Status}})" 2>/dev/null || true)
    if [ -n "$PG_STOPPED" ]; then
      check_warn "Postgres container exists but is stopped:"
      echo "$PG_STOPPED" | while read -r line; do
        echo "         $line"
      done
    else
      check_warn "No Postgres container found (may not be using Docker for DB)"
    fi
  fi
else
  check_warn "Docker not available — skipping container check"
fi

echo ""

# ─── CHECK 3: UNLEASH CONTAINER ───────────────────────────────────────────────

echo "3. Unleash Container"

COMPOSE_FILE="$BACKEND_ROOT/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  check_warn "No docker-compose.yml found — Unleash may be external"
elif ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
  check_warn "Docker not available — skipping Unleash container check"
else
  UNLEASH_CONTAINERS=$(docker ps --filter "name=unleash" --format "{{.Names}} ({{.Status}})" 2>/dev/null || true)
  if [ -n "$UNLEASH_CONTAINERS" ]; then
    check_pass "Unleash container(s) found:"
    echo "$UNLEASH_CONTAINERS" | while read -r line; do
      echo "         $line"
    done
  else
    UNLEASH_STOPPED=$(docker ps -a --filter "name=unleash" --format "{{.Names}} ({{.Status}})" 2>/dev/null || true)
    if [ -n "$UNLEASH_STOPPED" ]; then
      check_warn "Unleash container exists but is stopped"
    else
      check_warn "No Unleash container found — feature flags will use DB/default cascade"
    fi
  fi
fi

echo ""

# ─── CHECK 4: REQUIRED ENV VARIABLES ──────────────────────────────────────────

echo "4. Backend Environment Variables"

REQUIRED_VARS=(
  "DATABASE_URL"
  "JWT_SECRET"
  "UNLEASH_URL"
  "UNLEASH_API_TOKEN"
  "UNLEASH_APP_NAME"
  "UNLEASH_INSTANCE_ID"
)

if [ -f "$ENV_FILE" ]; then
  for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
      VALUE=$(grep "^${var}=" "$ENV_FILE" | head -1 | cut -d'=' -f2-)
      if [ -z "$VALUE" ]; then
        check_fail "$var is set but empty"
      else
        MASKED="${VALUE:0:4}****"
        check_pass "$var = $MASKED"
      fi
    else
      check_fail "$var is missing from $ENV_FILE"
    fi
  done
else
  check_fail "Backend .env file not found at $ENV_FILE"
fi

echo ""

# ─── CHECK 5: FEATURE FLAGS ENDPOINT ──────────────────────────────────────────

echo "5. Backend Feature Flags Endpoint"

BACKEND_PORT="3010"
if [ -f "$ENV_FILE" ]; then
  PORT_VAL=$(grep "^PORT=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
  if [ -n "$PORT_VAL" ]; then
    BACKEND_PORT="$PORT_VAL"
  fi
fi

HEALTH_URL="http://localhost:${BACKEND_PORT}/api/feature-flags/health"

if command -v curl &>/dev/null; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$HEALTH_URL" 2>/dev/null || echo "000")
  HTTP_NUM=$((10#${HTTP_CODE:-0} + 0)) 2>/dev/null || HTTP_NUM=0
  if [ "$HTTP_NUM" -eq 200 ]; then
    check_pass "Feature flags health endpoint responding (HTTP 200)"
  elif [ "$HTTP_NUM" -eq 401 ] || [ "$HTTP_NUM" -eq 403 ]; then
    check_pass "Backend is running (HTTP $HTTP_NUM — auth required, which is expected)"
  elif [ "$HTTP_NUM" -eq 0 ]; then
    check_warn "Backend not reachable at localhost:$BACKEND_PORT (not running?)"
  else
    check_warn "Feature flags endpoint returned HTTP $HTTP_NUM"
  fi
else
  check_warn "curl not available — cannot check endpoint"
fi

echo ""

# ─── SUMMARY ──────────────────────────────────────────────────────────────────

echo "===================="
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL critical check(s) failed."
  exit 1
else
  if [ "$WARN" -gt 0 ]; then
    echo "PASS (with warnings): Infrastructure checks passed."
  else
    echo "PASS: All infrastructure checks passed."
  fi
  exit 0
fi
