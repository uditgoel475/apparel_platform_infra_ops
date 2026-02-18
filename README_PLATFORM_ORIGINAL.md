# Apparel Platform

Multi-tenant SaaS ERP for apparel businesses. Modular architecture with feature flag isolation, fail-safe cascades, and guided onboarding.

## Stack

| Layer | Technology |
|-------|-----------|
| Backend | NestJS + Prisma + PostgreSQL |
| Frontend | React 18 + Vite + AG Grid |
| Feature Flags | Unleash (self-hosted) via backend proxy |
| Real-time | Socket.IO |
| Auth | JWT + RBAC (roles guard) |
| Containerization | Docker Compose |

## Modules

| Module | Flag Key | Routes |
|--------|----------|--------|
| Customers | `module.customers.enabled` | `/customer/*` |
| Orders & Returns | `module.orders.enabled` | `/orders/*` |
| Suppliers & Invoices | `module.suppliers.enabled` | `/supplier/*` |
| Products & Categories | `module.catalog.enabled` | `/catalog/*` |
| Administration | `module.administration.enabled` | `/administration/*` |
| Configurations | `module.config.enabled` | `/config/*` |
| Analytics Dashboard | `module.analytics.enabled` | `/dashboard/*` |

## Quick Start

```bash
# Start all services (Postgres, Backend, Unleash)
cd apparel_platform_backend
docker-compose up -d

# Run database migrations
npx prisma migrate deploy

# Seed Unleash flags
bash scripts/feature-flags/seed-unleash-flags.sh

# Start backend
npm run start:dev

# Start frontend (separate terminal)
cd ../apparel_platform_frontend
npm run dev
```

---

## Documentation

All documentation lives inside the product repositories. No root-level doc directories.

### Backend — [`apparel_platform_backend/`](apparel_platform_backend/)

| Category | Path | Contents |
|----------|------|----------|
| Feature Flags | [`docs/feature-flags/`](apparel_platform_backend/docs/feature-flags/) | Governance policy, Unleash environment strategy |
| Module Registry | [`docs/module-registry/`](apparel_platform_backend/docs/module-registry/) | ModuleRegistry design, module addition workflow |
| Fail Safety | [`docs/fail-safety/`](apparel_platform_backend/docs/fail-safety/) | Three-tier cascade architecture |
| Incident Recovery | [`runbooks/incident-recovery/`](apparel_platform_backend/runbooks/incident-recovery/) | Disaster recovery plan (5 scenarios) |
| Client Onboarding | [`runbooks/client-onboarding/`](apparel_platform_backend/runbooks/client-onboarding/) | Provisioning guide, checklists, troubleshooting |
| Flag Operations | [`runbooks/flag-operations/`](apparel_platform_backend/runbooks/flag-operations/) | Seeding, toggling, emergency kill switch |
| Test Matrix | [`test-matrix/`](apparel_platform_backend/test-matrix/) | Permutation testing guide (full + backend) |

### Frontend — [`apparel_platform_frontend/`](apparel_platform_frontend/)

| Category | Path | Contents |
|----------|------|----------|
| Feature Guard | [`docs/feature-guard/`](apparel_platform_frontend/docs/feature-guard/) | Provider architecture, error boundary pattern |
| Onboarding | [`docs/onboarding/`](apparel_platform_frontend/docs/onboarding/) | Flag filtering, step mapping |
| Flag Debugging | [`runbooks/frontend-debug/`](apparel_platform_frontend/runbooks/frontend-debug/) | Cascade verification, localStorage diagnostics |
| Test Matrix | [`test-matrix/`](apparel_platform_frontend/test-matrix/) | Frontend permutation test scenarios |

---

## Adding a New Module

Every new module **must** include all of the following before merge:

1. **Backend ModuleRegistry entry** — `apparel_platform_backend/src/modules/feature-flags/module-registry.ts`
2. **Frontend ModuleRegistry entry** — `apparel_platform_frontend/src/feature-flags/module-registry.ts`
3. **Guard integration** — `@UseGuards(FeatureFlagGuard)` + `@RequireFeature('module.xxx.enabled')`
4. **Onboarding steps** — `apparel_platform_frontend/src/onboarding/onboardingSteps.ts` with `requiredFlag`
5. **Permutation test entries** — Backend spec + frontend spec
6. **Documentation entry** — Add check to `apparel_platform_backend/scripts/validate-doc-structure.sh`
7. **DB entitlement + Unleash flag** — Migration row + `scripts/feature-flags/seed-unleash-flags.sh`

See `.cursor/rules/new-module-checklist.mdc` for enforcement.

---

## Validation

```bash
bash apparel_platform_backend/scripts/validate-doc-structure.sh
```

---

## Repository Structure

```
apparel-platform-2/
├── apparel_platform_backend/
│   ├── docs/
│   │   ├── feature-flags/          # Governance policy, Unleash strategy
│   │   ├── module-registry/        # Module definitions, addition workflow
│   │   └── fail-safety/            # Three-tier cascade design
│   ├── runbooks/
│   │   ├── incident-recovery/      # Disaster recovery plan
│   │   ├── client-onboarding/      # Client provisioning runbook
│   │   └── flag-operations/        # Flag seeding, toggling, kill switch
│   ├── scripts/
│   │   ├── feature-flags/          # seed-unleash-flags.sh
│   │   └── validate-doc-structure.sh
│   ├── test-matrix/                # Permutation testing guides
│   └── src/modules/                # NestJS modules
├── apparel_platform_frontend/
│   ├── docs/
│   │   ├── feature-guard/          # Provider architecture, error boundary
│   │   └── onboarding/             # Flag filtering, step mapping
│   ├── runbooks/
│   │   └── frontend-debug/         # Flag debugging procedures
│   ├── test-matrix/                # Frontend permutation tests
│   └── src/
│       ├── feature-flags/          # Provider, guards, hooks, registry
│       ├── onboarding/             # Product tour system
│       └── ui/                     # Components, pages, layout
├── apparel_platform_postgres/      # DB init scripts
└── .github/workflows/              # CI pipelines
```
