# Repository Purpose & Scope

## What This Repo Is

This is the **infrastructure and operations** repository for the Apparel Platform. It holds cross-cutting tooling, system documentation, and operational scripts that are NOT tied to a single product service.

## Ownership

- **Primary:** Platform / DevOps team
- **Contributors:** SRE, on-call engineers, architecture reviewers
- **Consumers:** All engineering teams, LLM systems, architecture review boards

## What Belongs Here

- Cross-repo health check scripts
- Root structure validation and cleanup tools
- Cross-repo test runners
- System brain exports and architecture snapshots
- CI workflow references and templates
- Operational runbooks that span backend + frontend
- Infrastructure-as-code (future: Terraform, Helm, etc.)

## What NEVER Belongs Here

| Category | Reason | Correct Location |
|----------|--------|------------------|
| Backend source code (`src/`) | Product code | `apparel_platform_backend/` |
| Frontend source code (`src/`) | Product code | `apparel_platform_frontend/` |
| Database schemas / migrations | Product data | `apparel_platform_backend/prisma/` |
| Docker Compose files | Service config | `apparel_platform_backend/docker-compose.yml` |
| `.env` files or secrets | Security | Vault / env injection, never committed |
| `node_modules/` | Build artifact | Generated, gitignored |
| Product-specific docs | Owned by product | `apparel_platform_backend/docs/` or `apparel_platform_frontend/docs/` |
| Product-specific runbooks | Owned by product | `apparel_platform_backend/runbooks/` or `apparel_platform_frontend/runbooks/` |
| Feature flag governance | Backend-owned | `apparel_platform_backend/docs/feature-flags/` |

## Scope Boundaries

```
This repo:       Tooling that operates ON repos, not IN repos
Product repos:   Code that runs AS the product
Postgres repo:   Database initialization scripts
```

## Relationship to Product Repos

This repo has **no runtime dependency** on product repos. Product repos have **no dependency** on this repo. Scripts here may reference product repo paths (for validation), but they are standalone executables.
