# COMPLETE SYSTEM BRAIN EXPORT

> **Generated:** 2026-02-18  
> **Repository:** apparel-platform-2  
> **Architecture Style:** Modular Monolith  
> **Domain:** B2B Apparel ERP SaaS

---

# SECTION 1 — BUSINESS DOMAIN BRAIN

## Product Purpose

This platform solves the operational management problem for apparel businesses (manufacturers, distributors, retailers). It provides a single system to manage the full order-to-cash and procure-to-pay lifecycle: customer acquisition, order processing, supplier management, product cataloging, inventory tracking, shipping, tax compliance, invoicing, returns/credit-note processing, warehouse management, and financial analytics.

The SaaS model enables per-client module activation via feature flags, allowing the same codebase to serve clients with different operational needs (e.g., a pure retailer doesn't need supplier invoicing).

## Business Entities

### Customers (`customers` table)
- **Lifecycle:** Created → has addresses → places orders → may request returns → receives credit notes
- **Fields:** business_id, first/last name, email, phone, gender, DOB, GSTIN, notes
- **Relations:** addresses (1:N), orders (1:N), credit_notes (1:N), returns (1:N)
- **File:** `apparel_platform_backend/src/modules/customers/`

### Orders (`orders` table)
- **Lifecycle:** NEW → APPROVED → SENT_TO_WAREHOUSE → PACKED → DISPATCHED → DELIVERED → (CANCELLED | REQUEST_RETURN)
- **Fields:** business_id, customer_id, channel_id, warehouse_id, order_date, status, invoice_number, tax/shipping/subtotal/grand_total, billing/shipping address IDs, notes, cancel_reason
- **Relations:** order_items (1:N), order_items_statuses (1:N), customer (N:1), warehouse (N:1), channel (N:1), returns (1:N), order_returns (1:N), order_payments (1:N), shipments (1:N)
- **File:** `apparel_platform_backend/src/modules/orders/`

### Products (`products` table)
- **Lifecycle:** Created → categorized → listed on channels → priced → ordered → potentially returned
- **Fields:** business_id, category_id, base_sku, name, description, color, material, pattern, care_instructions, weight, HS code, active, return_policy, return_window_days
- **Relations:** category (N:1), inventory (1:N per warehouse), order_items (1:N), listings (1:N per channel), prices (1:N per channel), supplier_invoice_items (1:N), returns (1:N)
- **File:** `apparel_platform_backend/src/modules/products/`

### Suppliers (`suppliers` table)
- **Lifecycle:** Created → receives invoices → supplies products
- **Fields:** business_id, name, contact_name, email, phone, address, active
- **Relations:** supplier_invoices (1:N)
- **File:** `apparel_platform_backend/src/modules/suppliers/`

### Supplier Invoices (`supplier_invoices` table)
- **Lifecycle:** Created with items → PDF generated → tracked
- **Fields:** business_id, supplier_id, warehouse_id, invoice_number, invoice_date, subtotal/tax/total
- **Relations:** supplier_invoice_items (1:N with product), supplier (N:1), warehouse (N:1)
- **File:** `apparel_platform_backend/src/modules/supplier-invoices/`

### Warehouses (`warehouses` table)
- **Lifecycle:** Created → holds inventory → fulfills orders → dispatches shipments
- **Fields:** business_id, name, address, phone, contact_name, active, warehouse_short_id
- **Relations:** inventory (1:N), orders (1:N), order_items_statuses (1:N), supplier_invoices (1:N), channels (1:N default)
- **File:** `apparel_platform_backend/src/modules/warehouses/`

### Returns (`returns` table)
- **Lifecycle:** Requested → Approved/Rejected → Credit note issued
- **Fields:** business_id, order_id, product_id, quantity, reason, status, kind, refund_amount
- **Statuses:** PENDING, APPROVED, REJECTED, COMPLETED
- **Relations:** order (N:1), product (N:1), credit_note (1:1)
- **File:** `apparel_platform_backend/src/modules/returns/`

### Credit Notes (`customer_credit_notes` table)
- **Lifecycle:** Issued on return approval → consumable against future orders → expires
- **Fields:** business_id, customer_id, return_id, issue_date, expiry_date, amount_total, amount_consumed, consumable_amount
- **Relations:** customer (N:1), return (1:1), logs (1:N), order_returns (1:N)
- **File:** `apparel_platform_backend/src/modules/customers/` (credit notes managed within customers module)

### Expenses (`expenses` table)
- **Lifecycle:** Recorded → tracked against admin users
- **Fields:** business_id, title, type, type_other, amount, currency, spent_at, notes
- **Types:** Enum-driven (with "other" freetext)
- **File:** `apparel_platform_backend/src/modules/expenses/`

### Shipments (`shipments` table)
- **Lifecycle:** Created for order → tracking assigned → status updated (PENDING → IN_TRANSIT → DELIVERED)
- **Fields:** business_id, order_id, courier_company_id, courier_partner_id, tracking_id, status, source, destination
- **Relations:** order (N:1), courier_company (N:1), courier_partner (N:1)
- **File:** `apparel_platform_backend/src/modules/shipments/`

### Taxes (`taxes` table)
- **Lifecycle:** Configured → applied to orders based on applicability logic
- **Fields:** business_id, name, country, region_code, rate_percent, applicability_logic (INTRASTATE/INTERSTATE/ALL), effective_from/to
- **File:** `apparel_platform_backend/src/modules/taxes/`

### Channels (`channels` table)
- **Purpose:** Sales channels (Website, Amazon, Flipkart, etc.)
- **Fields:** business_id, name, url, currency, default_warehouse_id, active, channel_short_id
- **Relations:** orders (1:N), product_listings (1:N), product_prices (1:N), warehouse (N:1)

### Analytics
- **Implementation:** Computed at query time via `MetaService.getAnalyticsDashboard()`
- **No dedicated table** — aggregates from orders, expenses, supplier_invoices
- **Tabs:** Business Health, Operations, Money Out
- **File:** `apparel_platform_backend/src/modules/meta/meta.service.ts`

## End-to-End Business Flows

### Order-to-Cash Flow

```
Customer Created → Order Placed (NEW)
  → Order Approved (APPROVED) [OrdersService.confirmOrder]
  → Sent to Warehouse (SENT_TO_WAREHOUSE) [warehouse allocation]
  → Packed (PACKED) [warehouse processing]
  → Dispatched (DISPATCHED) [ShipmentsService creates shipment]
  → Delivered (DELIVERED) [shipment status update]
  → Payment Settled [PaymentsService.settle]
  → Invoice Generated [InvoicesService.generatePdfBuffer]
  → Analytics Updated [MetaService.getAnalyticsDashboard]
```

| Step | Business Intent | Implementation |
|------|----------------|----------------|
| Order creation | Customer wants products | `OrdersService.create` → validates inventory, applies tax, calculates totals |
| Order approval | Business confirms order | `OrdersService.confirmOrder` → changes status, creates order_items_status records |
| Warehouse dispatch | Ship products | `CouriersService.dispatchOrder` → creates shipment with tracking |
| Tax calculation | Legal compliance | `TaxesService.calculateTotalTaxRate` → INTRASTATE/INTERSTATE logic |
| Invoice generation | Legal document | `InvoicesService.renderPdf` → Puppeteer HTML-to-PDF |
| Payment recording | Cash collection | `PaymentsService.settle` → records payment source and transaction ref |

### Return-to-Credit Flow

```
Customer Requests Return → Return Created (PENDING)
  → Admin Reviews → Approved/Rejected
  → Credit Note Issued [auto on approval]
  → Credit Note Consumable Against Future Orders
  → Credit Note Expires [expiry_date]
```

### Procure-to-Pay Flow

```
Supplier Created → Supplier Invoice Created
  → Items Linked to Products → Inventory Updated
  → Invoice PDF Generated [SupplierInvoicesService.generatePdfBuffer]
```

## Client SaaS Customization Model

Each client (tenant) can have different modules enabled/disabled:

```
Tenant "default" → All 7 modules enabled
Tenant "retailer-a" → customers, orders, catalog ON; suppliers, admin OFF
Tenant "wholesaler-b" → All ON except analytics
```

**Mapping:** Feature flag key `module.xxx.enabled` → maps 1:1 to a business capability module. When disabled:
- Backend: API returns 403 on all endpoints for that module
- Frontend: Sidebar link hidden, route redirects to home, onboarding steps skipped
- Data: Remains in DB, just inaccessible via API/UI

---

# SECTION 2 — TECHNICAL ARCHITECTURE BRAIN

## System Architecture Style

**Modular Monolith** — single NestJS process, single PostgreSQL database, modules separated by NestJS module boundaries. No inter-service communication. All modules share the same Prisma client and database connection pool.

**NOT microservices.** All business logic runs in one process. The only external service dependency is Unleash (feature flags), which is optional (system fails open without it).

## Runtime Topology

```
┌─────────────────────────────────────────────────────┐
│ Docker Compose                                      │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐│
│  │ Postgres │  │ Unleash  │  │ Unleash Postgres   ││
│  │ :5432    │  │ :4242    │  │ :5433              ││
│  │ Vol:     │  │          │  │ Vol:               ││
│  │ pgdata   │  │          │  │ unleash_pgdata     ││
│  └────┬─────┘  └────┬─────┘  └────────────────────┘│
│       │              │                               │
│  ┌────┴──────────────┴─────┐  ┌────────────────────┐│
│  │ Backend (NestJS) :3000  │  │ Frontend (Vite)    ││
│  │ JWT Auth                │  │ :5173 (dev)        ││
│  │ Socket.IO               │  │ :3000 (vite conf)  ││
│  │ Unleash SDK             │  │ Axios → Backend    ││
│  └─────────────────────────┘  └────────────────────┘│
└─────────────────────────────────────────────────────┘
```

**docker-compose.yml:** `apparel_platform_backend/docker-compose.yml`

| Service | Image | Port | Volume |
|---------|-------|------|--------|
| postgres | postgres:14 | 5432 | pgdata |
| unleash-db | postgres:14 | 5433 | unleash_pgdata |
| unleash | unleashorg/unleash-server | 4242 | — |
| backend | Build from `.` | 3000 | — |
| frontend | Build from `../apparel_platform_frontend` | 5173 | — |

## Backend Deep Technical

### Module Map (22 NestJS modules)

| Module | Controller Prefix | Feature Flag Guard | Flag Key |
|--------|------------------|-------------------|----------|
| AuthModule | `/auth` | No | — |
| AdminUsersModule | `/admin-users` | Yes | `module.administration.enabled` |
| OrdersModule | `/orders` | Yes | `module.orders.enabled` |
| CustomersModule | `/customers` | Yes | `module.customers.enabled` |
| ProductsModule | `/products` | Yes | `module.catalog.enabled` |
| CategoriesModule | `/categories` | Yes | `module.catalog.enabled` |
| SuppliersModule | `/suppliers` | Yes | `module.suppliers.enabled` |
| SupplierInvoicesModule | `/supplier-invoices` | Yes | `module.suppliers.enabled` |
| WarehousesModule | `/warehouses` | Yes | `module.administration.enabled` |
| ExpensesModule | `/expenses` | Yes | `module.administration.enabled` |
| TaxesModule | `/taxes` | Yes | `module.config.enabled` |
| ShippingConfigModule | `/shipping-config` | Yes | `module.config.enabled` |
| ShipmentsModule | `/shipments` | Yes | `module.orders.enabled` |
| ReturnsModule | `/returns` | Yes | `module.orders.enabled` |
| MetaModule | `/meta` | No | — |
| PaymentsModule | `/payments` | No | — |
| InvoicesModule | `/invoices` | No | — |
| CouriersModule | `/couriers` | No | — |
| OptionsModule | `/options` | No | — |
| FeatureFlagsModule | `/feature-flags` | No | — |
| DataSyncModule | — (WebSocket) | No | — |
| NotificationsModule | — (service only) | No | — |

### Database Tables (31 tables)

`admin_users`, `admin_sessions`, `audit_logs`, `categories`, `channels`, `courier_companies`, `courier_partners`, `customer_addresses`, `customer_credit_notes`, `customer_credit_notes_logs`, `customers`, `expenses`, `id_sequences`, `inventory`, `module_entitlements`, `options`, `order_items`, `order_items_status`, `order_payments`, `order_returns`, `orders`, `products`, `product_listings`, `product_prices`, `returns`, `shipments`, `shipping_config`, `supplier_invoice_items`, `supplier_invoices`, `suppliers`, `system_settings`, `taxes`, `warehouses`

### PostgreSQL Extensions

`citext`, `pgcrypto`, `ltree`, `btree_gist`, `btree_gin`

### Middleware Stack (per request)

```
Request → RequestContextMiddleware (assigns x-request-id / uuid)
  → Helmet (security headers, from main.ts)
  → Global prefix "/api"
  → CORS (enabled in main.ts)
  → AuthGuard('jwt') [per-controller]
  → RolesGuard [per-controller]
  → FeatureFlagGuard [per-controller]
  → Controller handler
```

### Security Layers

1. **Helmet** — HTTP security headers (`main.ts`)
2. **CORS** — enabled (`main.ts`)
3. **JWT Auth** — `passport-jwt`, token from `Authorization: Bearer` header
4. **Session validation** — JWT strategy checks `admin_sessions.is_active` and `token_jti`
5. **Role-based access** — `RolesGuard` checks `@Roles()` decorator, SUPERADMIN bypasses
6. **Feature flag gate** — `FeatureFlagGuard` checks `@RequireFeature()` decorator
7. **Password hashing** — `bcrypt` (in AuthService)

### Real-Time (WebSocket)

**SessionGateway** (`/sessions` namespace):
- Online user tracking
- Session conflict resolution (duplicate login detection)
- Events: `online_users_changed`, `session_conflict`, `force_logout`

**DataSyncGateway** (`/data-sync` namespace):
- Entity change broadcasting
- Events: `entity_changed` (entity, action, id, timestamp)
- Used for real-time grid updates across browser tabs

### Scheduled Jobs

**ArchiveScheduler** — Cron-based (from `@nestjs/schedule`), registered in `app.module.ts`

### PDF Generation

**Puppeteer** — used in `InvoicesService` and `SupplierInvoicesService` for HTML-to-PDF rendering. Heavyweight dependency (ships Chromium).

### Business ID System

**IdSystemModule** → `BusinessIdGenerator` — generates formatted IDs like `CUS-2602-000005`, `ORD-2602-000012`. Uses `id_sequences` table for atomic counter increment per entity type + year-month.

## Frontend Deep Technical

### Provider Hierarchy

```
<ThemeProvider>
  <NotificationProvider>
    <RouterProvider>
      <RequireAuth>
        <ShellLayout>
          <FeatureFlagProvider>
            <OnboardingProvider>
              {children}
            </OnboardingProvider>
          </FeatureFlagProvider>
        </ShellLayout>
      </RequireAuth>
    </RouterProvider>
  </NotificationProvider>
</ThemeProvider>
```

### API Client

**File:** `src/config/api.ts`

- Axios instance, base URL from `VITE_API_BASE_URL` or `http://localhost:3000`
- Timeout: 10s
- Request interceptor: adds `Authorization: Bearer ${localStorage.token}`
- Response interceptor: 401/403 → clears localStorage (`token`, `role`, `admin_id`, `jti`) → redirects to `/login`

### State Management

**No global state library** (no Redux, no Zustand). State is managed via:
- `localStorage` for auth tokens, theme, onboarding step, feature flag cache
- React Context for theme, notifications, feature flags, onboarding
- Component-local `useState`/`useEffect` for page data

### Component Library

**No external component library.** All UI is hand-built with:
- CSS variables for theming (light/dark)
- AG Grid (Community) for data tables
- AG Charts (Community) for analytics
- Draft.js for rich text editing
- Custom modal/drawer/form components

### Feature Guard Design

Two-layer protection per module:
1. **FeatureGuardInner** — checks `isEnabled(flag)` from context, renders children or fallback
2. **FeatureErrorBoundary** — wraps inner, catches runtime errors from child components, renders fallback instead of crashing

**Usage patterns:**
- Sidebar: `<FeatureGuard flag="module.xxx.enabled">{NavLink}</FeatureGuard>` — hidden if disabled
- Routes: `<FeatureGuard flag="..." fallback={<Navigate to="/" />}>{Outlet}</FeatureGuard>` — redirect if disabled

### Error Boundary Strategy

Only `FeatureErrorBoundary` exists (in `FeatureGuard.tsx`). **No global error boundary.** If a non-guarded component throws, the entire app crashes.

---

# SECTION 3 — FEATURE FLAG + CLIENT CONFIG BRAIN

## Flag Evaluation Architecture

### Backend (Three-Tier Cascade)

**File:** `apparel_platform_backend/src/modules/feature-flags/feature-flags.service.ts`

```
isEnabled(flagKey, user)
    │
    ├─ Tier 1: Unleash SDK (unleash-client)
    │    SDK connected? → client.isEnabled(flagKey, context)
    │    Context: { userId, properties: { tenantId, role } }
    │    Refresh interval: 15 seconds
    │    │
    │    └─ Fails/unavailable → fall through
    │
    ├─ Tier 2: DB Entitlements (module_entitlements table)
    │    In-memory cache, TTL: 60 seconds
    │    Checks: tenant_id match, module_key match, enabled boolean, expires_at
    │    Expired entitlement → treated as disabled
    │    │
    │    └─ Not found → fall through
    │
    └─ Tier 3: ModuleRegistry Default
         getModuleByKey(flagKey).defaultEnabled
         All 7 modules default to: true (FAIL-OPEN)
```

### Frontend (Four-Tier Cascade)

**File:** `apparel_platform_frontend/src/feature-flags/FeatureFlagProvider.tsx`

```
fetchFlags() on mount + 60s polling
    │
    ├─ Tier 1: API fetch (GET /api/feature-flags)
    │    Success → use response, write to localStorage cache
    │    │
    │    └─ Fails → fall through
    │
    ├─ Tier 2: Fresh localStorage cache
    │    feature_flags_ts < 10 minutes old
    │    Validates: is JSON object, all values are boolean
    │    │
    │    └─ Missing or stale → fall through
    │
    ├─ Tier 3: Stale localStorage cache
    │    feature_flags_ts > 10 minutes old
    │    Same validation, logged as warning
    │    │
    │    └─ Missing or corrupt → fall through
    │
    └─ Tier 4: ModuleRegistry defaults
         getModuleDefault(key)
         All 7 modules default to: true (FAIL-OPEN)
```

### Cache Keys (localStorage)

| Key | Value | Purpose |
|-----|-------|---------|
| `feature_flags` | `{"module.customers.enabled": true, ...}` | Flag state cache |
| `feature_flags_ts` | ISO timestamp string | Cache freshness |
| `onboarding_step` | Number (-1 = done, 0 = fresh) | Tour progress |

## Client Entitlement Mapping

**Table:** `module_entitlements`

```sql
tenant_id   VARCHAR(100)  -- e.g., 'default', 'tenant-abc'
module_key  VARCHAR(100)  -- e.g., 'module.customers.enabled'
enabled     BOOLEAN       -- license status
expires_at  TIMESTAMPTZ   -- nullable, NULL = never expires
```

**Constraint:** `UNIQUE(tenant_id, module_key)`

**Current state:** Only `default` tenant exists (single-tenant deployment). The `tenant_id` field on `module_entitlements` is the ONLY tenant identifier in the entire database. No other table has `tenant_id`.

## Offline / Outage Survival Model

| Scenario | Backend Behavior | Frontend Behavior |
|----------|-----------------|-------------------|
| Unleash down | DB entitlements → defaults (fail-open) | No change (backend proxies) |
| DB down | Cached entitlements (60s) → defaults | Cached flags → stale cache → defaults |
| Backend down | N/A | Cached flags → stale cache → defaults |
| All down | N/A | Registry defaults (all enabled) |
| Corrupt localStorage | N/A | Auto-clear, fall to next tier |

**Key guarantee:** System NEVER locks out users. Worst case = all modules visible (fail-open).

---

# SECTION 4 — EXTENSION SURFACE MAP

## Safe Extension Points

### Adding a New Module (SAFE — well-documented)

Checklist enforced by Cursor rule (`.cursor/rules/new-module-checklist.mdc`):
1. Backend ModuleRegistry entry
2. Frontend ModuleRegistry entry
3. Controller with `@RequireFeature` guard
4. Onboarding steps with `requiredFlag`
5. Permutation test entries
6. Documentation entry in validation script
7. DB entitlement migration + Unleash flag

### Adding New API Endpoints to Existing Modules (SAFE)

Standard NestJS controller pattern. Inherits class-level guards automatically.

### Adding New Channels/Warehouses (SAFE)

Database-driven. No code changes needed. CRUD via existing APIs.

### Adding New Tax Rules (SAFE)

Database-driven with `applicability_logic` enum (INTRASTATE/INTERSTATE/ALL). No code changes for standard rules.

## Dangerous Extension Points

### Adding Cross-Module Business Logic (DANGEROUS)

Modules share the Prisma client but have no formal inter-module communication pattern. Service A calling Service B requires manual dependency injection. No event bus, no saga pattern. Risk of circular dependencies.

**Example risk:** If OrdersService needs to check inventory in a new way, it directly queries the Prisma client rather than going through ProductsService. This creates invisible coupling.

### Modifying the ID System (DANGEROUS)

`BusinessIdGenerator` uses `id_sequences` table with `entity_type + year_month` atomicity. Changing format requires migration of all existing IDs across all tables that reference them.

### Adding Multi-Tenancy Beyond Flags (VERY DANGEROUS)

The `business_id` field exists on most tables but has NO foreign key constraint, NO dedicated tenants table, and NO row-level security. It's a VARCHAR column used as a logical partition with NO enforcement. Adding real multi-tenancy requires:
- Creating a tenants table
- Adding FK constraints to business_id on all 20+ tables
- Implementing Prisma middleware for tenant scoping
- Modifying all queries to filter by tenant

## Tightly Coupled Modules

| Module A | Module B | Coupling |
|----------|----------|---------|
| Orders | Returns | Returns reference order_id, product_id |
| Returns | Credit Notes | Credit note created on return approval (1:1) |
| Orders | Payments | Payments reference order_id |
| Orders | Shipments | Shipments reference order_id |
| Products | Categories | Products have category_id FK |
| Products | Inventory | Inventory is per product+warehouse |
| Products | Listings/Prices | Per product+channel |
| Supplier Invoices | Products | Invoice items reference product_id |

## Plugin Architecture Potential

Currently: **None.** All modules are compiled together. No dynamic loading, no plugin registry, no module manifest at build time.

Possible approach: The ModuleRegistry already defines module metadata. Could be extended with:
- Lazy-loaded frontend route chunks (currently all eagerly imported)
- Dynamic NestJS module loading based on entitlements
- Module-specific database migrations

---

# SECTION 5 — FAILURE MODE REALITY MAP

## Unleash Down

| Aspect | Impact |
|--------|--------|
| Detection | Health endpoint: `GET /api/feature-flags/health` → `unleashReady: false` |
| User impact | None if DB entitlements are healthy. Flags serve from DB cache (60s TTL) then defaults. |
| Data risk | None. Unleash is read-only from backend's perspective. |
| Recovery | Restart Unleash container. Backend auto-reconnects on next SDK refresh cycle (15s). |
| Blind spot | If Unleash was the ONLY source that had a module disabled, and Unleash goes down, the module will RE-ENABLE (fail-open). This is BY DESIGN but could surprise operators. |

## Database Down

| Aspect | Impact |
|--------|--------|
| Detection | All API calls fail with 500. Prisma connection errors in logs. |
| User impact | Total application failure. No data reads or writes. |
| Data risk | In-flight transactions may be lost. Prisma uses transactions for multi-table operations. |
| Recovery | Restore PostgreSQL. Prisma reconnects automatically. |
| Blind spot | Feature flag entitlement cache (60s in-memory) means flags continue serving briefly, but all other operations fail immediately. |

## Backend Down

| Aspect | Impact |
|--------|--------|
| Detection | Frontend API calls fail. Axios interceptor may trigger logout on repeated failures. |
| User impact | Complete loss of functionality. Frontend shows cached data briefly then errors. |
| Data risk | None beyond in-flight requests. |
| Recovery | Restart backend. Stateless (except in-memory flag cache, rebuilds in 60s). |
| Blind spot | Frontend polling for flags (60s) will use cached flags. But ALL other API calls fail, so the app is effectively dead. |

## Flags Partially Available

| Aspect | Impact |
|--------|--------|
| Scenario | Unleash returns some flags but not others (partial SDK data). |
| User impact | Missing flags fall through to DB entitlements or defaults. Modules stay accessible. |
| Data risk | None. |
| Blind spot | If a flag is intentionally disabled in Unleash but the DB entitlement says enabled, Unleash wins (it's Tier 1). If Unleash is partially available, some flags evaluate from Tier 1 and others from Tier 2, creating inconsistent behavior across modules. |

## Docker Infrastructure Degraded

| Aspect | Impact |
|--------|--------|
| Postgres volume lost | Total data loss. No backup system implemented. |
| Unleash DB volume lost | Flag configuration lost. Must re-seed with `seed-unleash-flags.sh`. |
| Container OOM | Individual service restart. Docker restart policy not configured in compose file. |
| Network partition | Backend loses DB/Unleash connectivity. Same as "DB Down" / "Unleash Down" above. |

---

# SECTION 6 — SECURITY + TRUST MODEL

## Auth Flow

```
LoginPage → POST /api/auth/login { username, password, deviceInfo }
    → AuthService.loginWithSessionCheck()
    → bcrypt.compare(password, password_hash)
    → Check existing active sessions
       → If conflict: return tempToken for session resolution
       → If clear: create JWT + session record
    → JWT payload: { sub: admin_id, username, role, jti }
    → Response: { token, admin_id, role, jti }
    → Frontend stores in localStorage: token, admin_id, role, jti
```

## Token Flow

| Aspect | Value |
|--------|-------|
| Algorithm | HS256 (HMAC-SHA256) |
| Secret | `JWT_SECRET` env var (`"super-secret-key"` in dev — **RISK**) |
| Expiry | Set in JwtModule config |
| Storage | `localStorage.token` — **NOT httpOnly cookie** |
| Transmission | `Authorization: Bearer ${token}` header |
| Validation | JwtStrategy: extract → verify → load admin from DB → check session active → touch session `last_active_at` |
| Revocation | Session-based: deactivate `admin_sessions` record. Token itself cannot be revoked until expiry. |

## Secret Storage

| Secret | Location | Status |
|--------|----------|--------|
| `JWT_SECRET` | `.env` file, docker-compose env | **RISK:** Hardcoded `"super-secret-key"` in dev, same value likely used in staging. `.env` is gitignored. |
| `DATABASE_URL` | `.env` file | Contains plaintext password |
| `UNLEASH_API_TOKEN` | `.env` file | Default insecure token in dev |
| Password hashes | `admin_users.password_hash` column | bcrypt, proper |

## Internal Service Trust Assumptions

- **Backend trusts JWT implicitly** after signature verification + session check. No additional per-request authorization beyond role checks.
- **Frontend trusts backend responses** without validation. No response schema validation (Zod, etc.).
- **WebSocket auth** uses same JWT from handshake. No per-message auth.
- **No API rate limiting.** No request throttling middleware.
- **No CSRF protection** — JWT in header (not cookie) makes CSRF less relevant, but XSS can steal localStorage tokens.
- **SUPERADMIN bypasses all role checks.** Single superadmin compromise = full access.

---

# SECTION 7 — OPERATIONAL REALITY

## CI Enforcement

**File:** `.github/workflows/validate-docs.yml`

Two-job pipeline on push/PR to `main`/`develop`:
1. `validate-structure` — runs `scripts/validate-root-structure.sh` (fails if unexpected root directories)
2. `validate-docs` — runs `apparel_platform_backend/scripts/validate-doc-structure.sh` (fails if 15 required docs missing)

**NOT enforced by CI:**
- Unit tests (no test job in workflow)
- Linting (no lint job)
- TypeScript compilation (no build job)
- E2E tests
- Security scanning

## Repo Safety Scripts

| Script | Path | Purpose | Idempotent |
|--------|------|---------|-----------|
| Root structure validator | `scripts/validate-root-structure.sh` | Ensures only allowed dirs at root | Yes |
| Runtime safety check | `scripts/runtime-safety-check.sh` | Read-only Docker/env/endpoint checks | Yes |
| Safe cleanup | `scripts/safe-root-cleanup.sh` | Dry-run + apply legacy dir removal | Yes |
| Master health check | `scripts/repo-health-check.sh` | Runs all checks in sequence | Yes |
| Doc validation | `apparel_platform_backend/scripts/validate-doc-structure.sh` | Verifies 15 required docs exist | Yes |
| Unleash seed | `apparel_platform_backend/scripts/feature-flags/seed-unleash-flags.sh` | Creates 7 module flags in Unleash | Yes (skips existing) |
| Smoke test | `apparel_platform_backend/scripts/smoke.sh` | HTTP smoke test against running backend | Yes |
| E2E smoke | `apparel_platform_backend/scripts/smoke_e2e.sh` | Full lifecycle E2E test | No (creates data) |
| Test runner | `run-tests.sh` (root) | Backend + frontend test suite | Yes |

## Health Checks

| Check | Endpoint/Method | Auth |
|-------|----------------|------|
| Backend alive | `GET /api/health` | None |
| Feature flags health | `GET /api/feature-flags/health` | SUPERADMIN |
| Feature flags detailed | `GET /api/feature-flags/detailed` | SUPERADMIN |
| Docker containers | `scripts/runtime-safety-check.sh` | N/A |

## Runbook Maturity

| Runbook | Lines | Coverage | Maturity |
|---------|-------|----------|----------|
| Disaster Recovery Plan | 222 | 5 scenarios (Unleash, DB, cache, partial deploy, bad toggle) | Good — detection + action + recovery + postmortem for each |
| Client Onboarding | 221 | Full provisioning lifecycle | Good — checklists, troubleshooting tables |
| Flag Operations | 125 | Seeding, toggling, kill switch, troubleshooting | Adequate |
| Frontend Debug | 126 | Cache inspection, cascade verification, common issues | Adequate |

---

# SECTION 8 — KNOWN BAD / RISK AREAS (MANDATORY)

## Technical Debt

1. **No global error boundary in frontend.** Only `FeatureErrorBoundary` exists inside `FeatureGuard`. A throw in any non-guarded component (login page, shell layout itself, theme provider) crashes the entire app with a white screen.

2. **All page components eagerly imported in App.tsx.** No `React.lazy()`, no code splitting. The entire app loads on first paint regardless of which module the user needs. Bundle size grows linearly with every new page.

3. **No API response validation.** Frontend trusts backend responses completely. No Zod, no io-ts, no runtime type checking. A backend schema change silently breaks the frontend.

4. **PDF generation via Puppeteer.** Ships an entire Chromium binary (~300MB). Each PDF render spawns a headless browser. Memory-intensive, slow, and a known source of OOM crashes under load.

5. **`business_id` is a loose convention, not enforced.** Most tables have `business_id VARCHAR` but it has NO foreign key, NO tenants table, NO row-level security. Cross-tenant data leakage is possible if query filters are missed.

6. **`localStorage` for auth tokens.** Vulnerable to XSS. Any cross-site script can steal the JWT. Industry best practice is httpOnly cookies.

7. **JWT secret is a static string.** No key rotation mechanism. Same secret across all environments in default config.

8. **No database backup strategy.** Docker volume `pgdata` is the only copy. No pg_dump cron, no WAL archiving, no point-in-time recovery.

9. **No migration rollback strategy.** Prisma migrations are forward-only. No down migration files. A bad migration requires manual SQL.

10. **No request rate limiting or throttling.** A single client can overwhelm the API.

## Scaling Bottlenecks

1. **Single Prisma connection pool** shared by all modules. High-traffic modules (orders, products) compete with low-traffic modules (settings, taxes) for connections.

2. **Synchronous tax calculation** on every order create/update. For multi-item orders across regions, this can be slow.

3. **Analytics computed on-the-fly.** `MetaService.getAnalyticsDashboard()` runs aggregate queries across orders, expenses, and supplier_invoices on every request. No caching, no materialized views. Will degrade as data grows.

4. **In-memory feature flag entitlement cache.** Works for single instance. Breaks with horizontal scaling (each instance has its own cache with different TTL timing).

5. **Socket.IO without Redis adapter.** WebSocket connections are pinned to a single process. Cannot scale horizontally without adding a Redis adapter for pub/sub.

## Single Points of Failure

1. **Single PostgreSQL instance.** No replication, no failover.
2. **Single Unleash instance.** No HA setup. (Mitigated by fail-open cascade.)
3. **Single backend process.** No clustering, no PM2, no load balancer.
4. **No CDN for frontend.** Served directly from Vite dev server or Docker container.

## Manual Ops Risks

1. **Unleash flag seeding is manual.** Must run `seed-unleash-flags.sh` after deployment. If forgotten, flags don't exist in Unleash and system falls to DB/defaults.
2. **Client onboarding is manual.** Must insert `module_entitlements` rows via SQL. No admin UI for entitlement management.
3. **No automated database migration on deploy.** Must manually run `npx prisma migrate deploy`.

## Feature Flag Misuse Risk

1. **Fail-open default means accidentally deleting Unleash flags re-enables modules.** If someone deletes a flag in Unleash that was the sole mechanism keeping a module disabled, the cascade falls through to defaults (enabled).
2. **No flag dependency graph.** Flags are independent. No way to express "if orders disabled, shipments must also be disabled."
3. **No audit trail for flag changes.** Unleash has its own audit log, but it's not integrated into the application's `audit_logs` table.
4. **Method-level `@RequireFeature('')` bypass.** Onboarding endpoints on AdminUsersController use `@RequireFeature('')` to bypass the class-level guard. This is a documented workaround but creates an implicit "empty string means bypass" convention that could be misused.

## Tenant Isolation Weaknesses

1. **No row-level security.** All queries run as the same PostgreSQL role with full table access.
2. **`business_id` filtering is application-enforced.** If a service method forgets the `WHERE business_id = ?` clause, cross-tenant data is exposed.
3. **Feature flag context uses `tenantId` from JWT/request.** But JWT has no `tenantId` field currently. The field defaults to `'default'`. True multi-tenancy requires JWT changes + auth flow changes.
4. **Single database.** All tenant data co-mingles in the same tables. No schema-per-tenant, no database-per-tenant isolation.

---

# SECTION 9 — FUTURE EVOLUTION MAP

## Can system become microservices?

**Feasibility:** Medium-High effort, but the modular structure helps.

**What helps:**
- Each module has its own controller/service boundary
- ModuleRegistry already defines module metadata
- Feature flags already gate each module independently
- No shared mutable state between modules (except database)

**What blocks:**
- Shared Prisma schema (all 31 tables in one schema file)
- Direct database joins across module boundaries (orders join customers, products, warehouses)
- No message queue / event bus for inter-module communication
- Invoice generation depends on order data + tax data + product data (cross-module query)
- `BusinessIdGenerator` is a shared singleton with atomic counter in a shared table

**Recommended path:** Extract stateless services first (PDF generation, tax calculation), then event-source the order lifecycle.

## Can feature flags become an entitlement service?

**Feasibility:** High — the foundation already exists.

**Current state:** `module_entitlements` table + `FeatureFlagsService` already function as a primitive entitlement service. What's missing:
- Admin UI for managing entitlements (currently raw SQL)
- Subscription plan model (no concept of "plan" → "modules")
- Billing integration
- Self-service tenant provisioning
- Entitlement change audit trail (beyond Unleash's own logs)

**Recommended path:** Build an admin API for CRUD on `module_entitlements`, add a `plans` table that maps plan → modules, add a tenant provisioning workflow.

## Can modules become marketplace plugins?

**Feasibility:** Low — requires significant architecture changes.

**What's needed:**
- Module packaging format (currently just NestJS module files)
- Dynamic module loading (currently all compiled together)
- Frontend lazy loading per module (currently all eagerly imported)
- Module-scoped database migrations (currently all in one schema)
- Module API contract (currently modules can access any table)
- Security sandbox for third-party code
- Module lifecycle hooks (install, enable, disable, uninstall)

**Recommended path:** First implement lazy loading + code splitting. Then define a module manifest format. Plugin marketplace is a 2+ year evolution.

---

# SECTION 10 — LLM INGEST METADATA

## Domain Tags

`apparel`, `erp`, `b2b`, `saas`, `multi-tenant`, `order-management`, `inventory`, `supply-chain`, `returns`, `credit-notes`, `tax-compliance`, `shipping`, `invoicing`, `analytics`, `feature-flags`, `onboarding`

## Stack Tags

`nestjs`, `typescript`, `react-18`, `vite`, `prisma`, `postgresql`, `unleash`, `socket.io`, `docker-compose`, `jwt`, `rbac`, `ag-grid`, `puppeteer`, `bcrypt`, `axios`, `css-variables`

## Ratings

| Dimension | Score | Justification |
|-----------|-------|---------------|
| Architecture complexity | 7/10 | Modular monolith with feature flags, fail-safe cascades, multi-tier caching, WebSockets, session conflict resolution |
| Operational maturity | 4/10 | Good runbooks and validation scripts, but no CI test pipeline, no database backups, no monitoring, no alerting, no APM, no log aggregation |
| Code quality | 6/10 | Consistent patterns, TypeScript throughout, but no linting in CI, no API response validation, some implicit conventions (empty string bypass) |
| Security posture | 4/10 | JWT auth works, bcrypt passwords, role-based access. But localStorage tokens, static JWT secret, no rate limiting, no CSRF, no security headers audit |
| Scalability readiness | 3/10 | Single-instance everything. In-memory caches, no connection pooling config, no horizontal scaling story, on-the-fly analytics |
| Documentation quality | 7/10 | 15 doc files covering architecture, governance, runbooks, testing. CI-enforced existence. But no API documentation (Swagger/OpenAPI), no inline JSDoc |
| Test coverage | 2/10 | Only 2 backend spec files, 1 frontend test file. No E2E test suite in CI. Smoke scripts exist but are manual. |
| Risk rating | HIGH | Single DB, no backups, no monitoring, weak tenant isolation, localStorage auth tokens |

---

# SECTION 11 — CRITICAL FILE MAP

## Backend — Core

| File | Purpose |
|------|---------|
| `apparel_platform_backend/src/main.ts` | NestJS bootstrap (CORS, Helmet, global prefix, Socket.IO adapter) |
| `apparel_platform_backend/src/app.module.ts` | Root module — imports all 22+ modules |
| `apparel_platform_backend/prisma/schema.prisma` | Database schema — 31 tables, enums, relations |
| `apparel_platform_backend/prisma/seed.ts` | Full seed: users, products, orders, customers, suppliers, taxes |
| `apparel_platform_backend/docker-compose.yml` | Postgres, Unleash, backend, frontend containers |
| `apparel_platform_backend/.env` | Runtime config (DB URL, JWT secret, Unleash config) |

## Backend — Feature Flags

| File | Purpose |
|------|---------|
| `apparel_platform_backend/src/modules/feature-flags/module-registry.ts` | 7 module definitions (key, label, routes, adminOnly, default) |
| `apparel_platform_backend/src/modules/feature-flags/feature-flags.service.ts` | Three-tier cascade evaluation (Unleash → DB → defaults) |
| `apparel_platform_backend/src/modules/feature-flags/feature-flags.guard.ts` | NestJS route guard — checks @RequireFeature metadata |
| `apparel_platform_backend/src/modules/feature-flags/feature-flags.decorator.ts` | @RequireFeature() decorator |
| `apparel_platform_backend/src/modules/feature-flags/feature-flags.controller.ts` | GET /flags, /detailed, /health |
| `apparel_platform_backend/src/modules/feature-flags/feature-flags.module.ts` | Global module export |

## Backend — Auth

| File | Purpose |
|------|---------|
| `apparel_platform_backend/src/modules/auth/auth.service.ts` | Login, session management, conflict resolution |
| `apparel_platform_backend/src/modules/auth/strategies/jwt.strategy.ts` | JWT validation + session check |
| `apparel_platform_backend/src/modules/auth/session.gateway.ts` | WebSocket session tracking |
| `apparel_platform_backend/src/common/guards/roles.guard.ts` | RBAC enforcement |

## Backend — Business Logic

| File | Purpose |
|------|---------|
| `apparel_platform_backend/src/modules/orders/orders.service.ts` | Order lifecycle (create → approve → dispatch → cancel) |
| `apparel_platform_backend/src/modules/orders/orders.controller.ts` | 20+ order endpoints |
| `apparel_platform_backend/src/modules/products/products.service.ts` | Product CRUD, listings, prices, inventory |
| `apparel_platform_backend/src/modules/customers/customers.service.ts` | Customer CRUD, addresses, credit notes |
| `apparel_platform_backend/src/modules/taxes/taxes.service.ts` | Tax calculation engine |
| `apparel_platform_backend/src/modules/invoices/invoices.service.ts` | PDF invoice generation (Puppeteer) |
| `apparel_platform_backend/src/modules/meta/meta.service.ts` | Analytics dashboard aggregation |
| `apparel_platform_backend/src/core/id-system/business-id.generator.ts` | Business ID generation (CUS-YYMM-NNNNN) |

## Frontend — Core

| File | Purpose |
|------|---------|
| `apparel_platform_frontend/src/ui/App.tsx` | Route definitions, auth guard, provider hierarchy |
| `apparel_platform_frontend/src/ui/layout/ShellLayout.tsx` | Shell layout, sidebar, topbar, feature guards, onboarding |
| `apparel_platform_frontend/src/config/api.ts` | Axios instance with auth interceptors |
| `apparel_platform_frontend/src/main.tsx` | Entry point |
| `apparel_platform_frontend/src/styles/theme.css` | CSS variables for light/dark theme |
| `apparel_platform_frontend/src/ui/app.css` | Global styles, AG Grid overrides |

## Frontend — Feature Flags

| File | Purpose |
|------|---------|
| `apparel_platform_frontend/src/feature-flags/FeatureFlagProvider.tsx` | Four-tier cascade provider |
| `apparel_platform_frontend/src/feature-flags/FeatureGuard.tsx` | Guard component + error boundary |
| `apparel_platform_frontend/src/feature-flags/useFeature.ts` | Hook for consuming flag state |
| `apparel_platform_frontend/src/feature-flags/module-registry.ts` | Frontend module definitions |

## Frontend — Onboarding

| File | Purpose |
|------|---------|
| `apparel_platform_frontend/src/onboarding/onboardingSteps.ts` | 47 step definitions with flag mapping |
| `apparel_platform_frontend/src/onboarding/OnboardingProvider.tsx` | Tour orchestration, flag filtering, route navigation |
| `apparel_platform_frontend/src/onboarding/OnboardingOverlay.tsx` | Spotlight overlay, tooltip rendering |
| `apparel_platform_frontend/src/onboarding/onboardingService.ts` | API calls + localStorage caching |

## Infrastructure

| File | Purpose |
|------|---------|
| `.github/workflows/validate-docs.yml` | CI: root structure + doc validation |
| `.cursor/rules/new-module-checklist.mdc` | Cursor rule: 7-item module addition checklist |
| `scripts/repo-health-check.sh` | Master health check wrapper |
| `scripts/validate-root-structure.sh` | Root directory allowlist enforcement |
| `scripts/runtime-safety-check.sh` | Read-only infra checks |
| `scripts/safe-root-cleanup.sh` | Safe legacy directory removal |
| `apparel_platform_backend/scripts/validate-doc-structure.sh` | 15-doc existence validation |
| `apparel_platform_backend/scripts/feature-flags/seed-unleash-flags.sh` | Unleash flag bootstrapping |
| `apparel_platform_postgres/00_extensions.sql` | PostgreSQL extension setup |
| `apparel_platform_postgres/01_init_bootstrap_apparel.sql` | Raw SQL database bootstrap |

## Tests

| File | Purpose |
|------|---------|
| `apparel_platform_backend/src/modules/feature-flags/feature-flags.service.spec.ts` | Backend flag cascade tests |
| `apparel_platform_backend/src/core/id-system/business-id.generator.spec.ts` | Business ID generation tests |
| `apparel_platform_frontend/src/feature-flags/__tests__/FeatureFlagProvider.test.tsx` | Frontend flag cascade + guard + onboarding filter tests |

---

*End of System Brain Export.*
