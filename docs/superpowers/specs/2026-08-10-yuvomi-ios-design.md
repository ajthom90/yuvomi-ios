# Yuvomi iOS — Design Spec

**Date:** 2026-08-10  
**Status:** Approved (design conversation); pending implementation plan  
**Repo:** `ajthom90/yuvomi-ios` (to be created public on GitHub)  
**Upstream server:** [ulsklyc/yuvomi](https://github.com/ulsklyc/yuvomi) (MIT, self-hosted family planner)

## 1. Problem & product

Yuvomi is a privacy-first, self-hosted household planner (tasks, calendar, shopping, meals, budget, health, and more) delivered today as a mobile-first PWA with a documented OpenAPI 3.0 API. There is no first-party native iOS client.

This project is a **fully native iOS app** that:

- Connects to the user’s self-hosted Yuvomi instance (no vendor cloud).
- Targets **full feature parity** with Yuvomi’s modules over time.
- Is **open source (MIT)** on GitHub so anyone can build it free.
- May also ship as a **paid App Store binary**; payment is optional packaging, not a license restriction on the source.

### Non-goals

- Shipping or bundling a Yuvomi server.
- Replacing CalDAV/CardDAV/Mealie/WebDAV/Paperless *servers*; the client only uses Yuvomi’s HTTP API.
- Pixel-perfect reproduction of the web “Liquid Glass” PWA.
- Offline write queues / multi-master sync (v1 architecture).
- Default analytics or any phone-home to a third-party backend.

## 2. Decisions (locked)

| Topic | Choice |
|--------|--------|
| Delivery | Foundation first, then phased full module parity |
| Auth | API token primary + username/password |
| Offline | Online-first with smart read-only cache |
| UI | Native SwiftUI, Yuvomi-inspired (accents + IA), not a PWA clone |
| Platform | iOS 18+ |
| Architecture | Modular SwiftUI client + OpenAPI-aligned networking |
| License | MIT |
| Default UI language | English first; structure for more later |
| Project stance | Community native client linked to upstream |

## 3. Architecture overview

### Approach

**Modular SwiftUI client + OpenAPI-generated types.**

- SwiftUI app with feature folders/modules per Yuvomi domain.
- Networking against `{serverURL}/api/v1` using models generated from upstream OpenAPI, plus a hand-written auth/error/upload adapter.
- Keychain for secrets; snapshot cache for last-known GETs.
- Module registry driven by server-enabled modules.

Rejected alternatives:

- WKWebView wrapper (not native; weak App Store story).
- Monolithic hand-written DTOs for all modules (does not scale to full parity).

### Layering

```
App (SwiftUI)
  ├── Features/*          # one area per module (Tasks, Shopping, …)
  ├── DesignSystem        # Yuvomi color families, shared components
  ├── AppShell            # tabs, More grid, routing, deep links
  └── Core
        ├── Auth          # token + session providers
        ├── Networking    # OpenAPI client + adapters
        ├── Cache         # last-known read snapshots
        └── Models        # shared domain types / generated API types
```

Features depend on **service protocols** (e.g. `TasksServing`), not the concrete HTTP client, so UI can be tested with fakes.

### Navigation shell

- **iPhone:** `TabView` with defaults **Home**, **Tasks**, **Shopping**, **Calendar**, **More**. Favorites become user-configurable later without changing the shell model.
- **iPad:** `NavigationSplitView` (module list + detail) with the same destinations.
- **More:** full module grid + Settings. Only modules the server reports as **enabled** are shown.
- **Deep links:** `yuvomi://` for invite accept, password reset, and open-by-id where the API supports it.

### First-run

1. Welcome → **Server URL** (HTTPS preferred; guidance for LAN / reverse proxy).
2. Auth: **API token** *or* **username/password**.
3. Validate with an authenticated bootstrap call → **Dashboard**.

## 4. Auth & security

### Modes

1. **API token (primary)**  
   - Created in Yuvomi web Settings → API Tokens.  
   - Sent as `Authorization: Bearer` and/or `X-API-Key` per OpenAPI.  
   - Stored **only in Keychain**.  
   - Prefer tokens with appropriate module scopes when the server supports them.

2. **Username / password**  
   - `POST /api/v1/auth/login` → session cookie + CSRF for state-changing calls.  
   - Cookie jar + CSRF header on mutating requests.  
   - Do **not** store the password by default; persist session material in Keychain for “stay signed in.”  
   - Logout: `POST /api/v1/auth/logout` + wipe Keychain session material.

### Session lifecycle

- Launch: restore token or session → validate → enter shell or login.
- **401/403:** clear invalid credentials, return to login with a clear message.
- **v1 profiles:** one active server profile (URL + auth + display name). Keychain accounts keyed by server host so multi-profile can be added later without redesign.

### Phased auth-adjacent flows

| Flow | Foundation | Later |
|------|------------|--------|
| API token | Yes | — |
| Password login | Yes | — |
| Accept invite | Thin in-app / deep link → API → login | Full polish |
| Forgot / reset password | Link/API if SMTP configured | Full in-app |
| OIDC | Out of foundation | `ASWebAuthenticationSession` when needed; document `BASE_URL` / redirect requirements |

### Transport & self-hosting

- ATS: HTTPS default.
- Self-signed / private PKI: explicit user opt-in **“Trust this server”** after showing certificate summary; challenge handling **scoped to that host** (no global ATS disable).
- Local Network usage description only if discovery is added later; foundation uses **manual URL**.
- No analytics in open-source default builds. Any future crash reporting is opt-in and documented for App Store privacy labels.
- Data leaves the device **only** for the user-configured server.

### Authorization in UI

- Role from member/me payload (admin vs member).
- Admin-only surfaces (invites, backup, module admin) gated in UI; **server 403 remains source of truth**.

## 5. Networking, models & cache

### API

- Base: `{serverURL}/api/v1/…` (normalize URL; avoid double `/api`).
- Source of truth: upstream OpenAPI under `server/openapi`.
- **Codegen** of Swift models/request stubs (e.g. swift-openapi-generator), regenerated when raising supported server version.
- Hand-written adapter for: auth injection, error mapping, multipart uploads, pagination helpers.

### Client shape

```
Feature ViewModel
  → ModuleAPI protocol (e.g. TasksServing)
    → YuvomiClient (shared URLSession)
      → AuthProvider
      → ResponseCache
```

- One shared `URLSession`; cookie storage used only in password mode.
- Swift `async/await`; `@MainActor` view models.
- Pull-to-refresh; optional silent refresh of the active tab on foreground.
- No aggressive background sync in foundation.

### Cache policy (online-first)

1. Network OK → fetch → update UI → write snapshot keyed by `(serverHost, userId, path+query)`.
2. Transport failure → show last snapshot + banner: offline / last updated.
3. Mutations require network; failures surface errors — **no offline write queue**.

Foundation cache coverage: dashboard, tasks, shopping, calendar, family members (needed cross-module). Other modules use the same cache helper as they land.

Settings: **Clear cache**; also wipe on logout and server change.

Storage: start with a simple durable snapshot store; prefer **SwiftData** once models stabilize.

### Compatibility

- Record minimum supported **Yuvomi server** version in README (initially current 2.x line).
- On connect, surface server/client version mismatch as a warning when detectable; do not hard-brick unless auth fails.

### Errors & empty states

Consistent: loading, empty, offline-cached, error-with-retry. Map 400/422 field errors into forms where possible.

### Testing

- Unit tests with fake services.
- Contract/fixture tests from OpenAPI samples.
- Optional Docker-backed integration tests in CI later.

## 6. Design system (native, Yuvomi-inspired)

- SwiftUI system materials, SF Symbols, Dynamic Type, light/dark.
- Accent **families** aligned with upstream DESIGN tokens (not a full CSS port):

  | Family | Modules (indicative) | Role |
  |--------|----------------------|------|
  | Overview indigo | Dashboard | Home |
  | Time violet | Calendar, Reminders | Schedule |
  | Work green | Tasks, Housekeeping, Rewards | Chores |
  | Kitchen orange | Meals, Recipes, Shopping, Pantry | Kitchen |
  | Money teal | Budget, Split expenses | Finance |
  | People pink | Contacts, Birthdays | People |
  | Health magenta | Health | Health |
  | Records slate | Documents, Notes | Files |
  | Neutral | Settings | System |

- Touch targets and readability follow HIG; module accent tints navigation/primary actions for the active area.
- Read-first detail screens; edit is a named second step (parity with upstream UX grammar).

## 7. Module roadmap & parity definition

### Cross-cutting behavior

- List → detail **read** → explicit **edit**.
- Assignees, avatars, visibility (only me / assignees / everyone) when API provides them.
- Search/filter when supported.
- Hide modules disabled on the server.

### Phases

| Phase | Focus | Deliverables | Done means |
|-------|--------|--------------|------------|
| **0 — Foundation** | Product shell | Connect, token + password auth, session restore, Dashboard, Settings (server/account/cache/about), module registry + placeholders, design tokens | Install → login → real dashboard; full nav map |
| **1 — Daily drivers** | High frequency | Tasks (list/kanban basics, subtasks, due, assign, complete), Shopping (lists, aisles, check-off), Calendar (month/agenda, basic create/edit) | Chores, groceries, appointments on phone |
| **2 — Kitchen loop** | Cross-module | Meals, Recipes, Pantry + export/handoff to shopping/stock | Week plan → shop → pantry without web |
| **3 — Money** | Finance | Budget (accounts, transactions, recurring, subscriptions, plans), Split expenses | Spend tracking + settle-up |
| **4 — People & health** | Members | Family, Contacts, Birthdays, Health, Rewards | Member-centric + privacy for health |
| **5 — Records & ops** | Files & ops | Notes, Documents (preview/upload), Housekeeping, Reminders (in-app + local notifications from fetched dues) | Notes/docs/staff usable on device |
| **6 — Admin & polish** | Store & edges | Invites UI, admin backup status, token management if API allows, global search, widget(s), a11y pass, App Store assets, i18n scaffolding | Credible “all features”; store-ready |

### Per-module depth order

1. Read (list + detail)  
2. Core write (create/update/delete/complete)  
3. Cross-module integrations  
4. Power features (bulk, import, edge recurrence, etc.)

Placeholders only for **not-yet-started** phases. Once a phase starts, modules in that phase are not left as permanent stubs.

### Explicit deferrals (supported later; not foundation blockers)

- OIDC sign-in  
- Offline write queue  
- APNs relay (Web Push / Gotify / ntfy do not map 1:1; start with **local notifications** from fetched reminder data; document server push options)  
- Multi-server account switcher UI  
- Full server-side integration config UIs (CalDAV credentials, Mealie URL, etc.) beyond what members need day-to-day  
- Pixel-perfect web glass chrome  

### “Supports all features” success criteria

- Every enabled Yuvomi module has a native path with core CRUD (or module equivalent).
- Kitchen loop and task→rewards points loop work end-to-end.
- Visibility/role rules are not bypassed client-side.
- README maintains **web feature → native status** during build-out.

## 8. Repository, license, App Store

### Repository layout

```
yuvomi-ios/
  README.md
  LICENSE
  CONTRIBUTING.md
  SECURITY.md
  docs/
    superpowers/specs/2026-08-10-yuvomi-ios-design.md
    architecture.md          # living notes (post-plan)
  Yuvomi/                    # Xcode app
  .github/workflows/         # xcodebuild test on PR
```

- Public GitHub repo under `ajthom90`.
- Not a fork of the server; document relationship and minimum server version.
- Issue labels by module and phase.

### License & commercial

- **MIT** source.
- Paid App Store binary allowed; source remains free to build.
- README states clearly that the store build is optional support for development.
- Third-party notices for dependencies and generated code.

### Branding

- Name: **Yuvomi** client with clear **community / native iOS client** positioning unless upstream later adopts it as official.
- Distinct app icon inspired by the project; credit upstream in About.
- Privacy Policy (static URL): no vendor backend; data only to user server — required for App Store.

### App Store technical notes

- Entitlements as needed: Keychain; Push only if APNs is ever added; Local Network only if discovery ships.
- Standard HTTPS export-compliance exemption.
- Account deletion: document server-side family/admin deletion path.
- No committed secrets, provisioning profiles, or personal server URLs.

### Contribution

- PRs welcome per module against the phase plan.
- CONTRIBUTING: local Yuvomi via Docker, running tests, regenerating OpenAPI client.
- CI: compile + unit tests; broader UI tests as the suite stabilizes.

## 9. Risk register

| Risk | Mitigation |
|------|------------|
| OpenAPI drift vs server releases | Pin minimum version; regenerate client; compatibility warnings |
| Cookie/CSRF friction on iOS | Prefer tokens; solid session adapter for password mode |
| Self-signed cert support abuse | Per-host opt-in trust UI, not global ATS off |
| Scope explosion (17 modules) | Hard phase gates; depth order per module |
| Push parity expectations | Document local vs server channels; no fake APNs |
| App Store “web wrapper” rejection | True native SwiftUI; no WKWebView shell |

## 10. Next steps after spec approval

1. Write implementation plan (phase 0 detailed tasks; later phases outlined).  
2. Create public GitHub repository and initial project scaffolding.  
3. Execute Phase 0 foundation, then Phase 1 daily drivers, continuing through the roadmap.

---

## Appendix A — Yuvomi modules (parity checklist)

| Module | Phase | Notes |
|--------|-------|--------|
| Dashboard | 0 | Real API widgets, not a static home |
| Settings / preferences | 0 | Server, account, cache, about |
| Tasks | 1 | Kanban/list, recurring, multi-assign |
| Shopping | 1 | Aisles, collaborative check-off |
| Calendar | 1 | Local Yuvomi events; sync config remains server-side |
| Meals | 2 | Weekly planner |
| Recipes | 2 | Scale, send to shopping / meals |
| Pantry | 2 | Stock, expiry, shopping handoff |
| Budget | 3 | Accounts, txns, subscriptions, plans |
| Split expenses | 3 | Groups, balances, settle |
| Family | 4 | Profiles, roles, invites (admin) |
| Contacts | 4 | Directory; CardDAV config server-side |
| Birthdays | 4 | Ages, calendar linkage |
| Health | 4 | Vitals, meds, cycle; visibility critical |
| Rewards | 4 | Points, catalog, ledger |
| Notes | 5 | Markdown notes |
| Documents | 5 | Upload, preview, folders |
| Housekeeping | 5 | Staff schedules, chores, supplies |
| Reminders | 5 | In-app + local notifications |
| API tokens / backup / search | 6 | Admin/polish |

## Appendix B — Auth API anchors (upstream)

Illustrative endpoints the client will use (full contract in OpenAPI):

- `POST /api/v1/auth/login`, `POST /api/v1/auth/logout`
- `POST /api/v1/auth/setup` (only if instance uninitialized; rare for client)
- Invite preview/accept, forgot/reset password
- OIDC config/start/callback (later)
- API tokens as documented under admin/API token paths

Bearer / `X-API-Key` for token mode; cookie + CSRF for password mode.
