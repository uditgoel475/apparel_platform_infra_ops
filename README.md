# Apparel Platform — Infrastructure & Operations

Operational tooling, system documentation, CI references, and cross-repo scripts for the Apparel Platform.

## Ownership

This repository is owned by the **Platform / DevOps team**. It contains no product source code.

## Contents

| Directory | Purpose |
|-----------|---------|
| `scripts/` | Repo health checks, runtime safety, root structure validation, cleanup automation |
| `brain_exports/` | System architecture exports for LLM ingestion, knowledge transfer, DR knowledge retention |
| `ci/` | CI workflow references (canonical copies live in product repos) |
| `tools/` | Cross-repo test runners and build tools |
| `runbooks/` | Operational runbooks that span multiple repos |

## Related Repositories

| Repository | Purpose |
|------------|---------|
| `apparel_platform_backend` | NestJS API server, Prisma schema, feature flag system, all backend docs/runbooks |
| `apparel_platform_frontend` | React SPA, feature guard system, onboarding tour, all frontend docs/runbooks |
| `apparel_platform_postgres` | Database init scripts and extensions |

## Scripts

```bash
bash scripts/repo-health-check.sh            # Master health check (structure + runtime + docs)
bash scripts/runtime-safety-check.sh          # Read-only infra checks
bash scripts/validate-root-structure.sh       # Root directory allowlist enforcement
bash scripts/safe-root-cleanup.sh             # Legacy directory cleanup (dry-run default)
bash tools/run-tests.sh                       # Cross-repo test runner
```

## Brain Exports

System architecture snapshots for knowledge transfer:

- `brain_exports/SYSTEM_BRAIN_EXPORT_FULL.md` — Complete system brain (903 lines, 11 sections)
