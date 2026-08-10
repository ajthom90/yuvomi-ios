# Yuvomi iOS Phase 0 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a buildable native iOS shell that connects to a self-hosted Yuvomi server, authenticates (API token or username/password), shows a real dashboard, navigates the full module map, and exposes Settings — foundation for full module parity.

**Architecture:** Modular SwiftUI app (iOS 18+) with Core (Auth, Networking, Cache, Models), DesignSystem, AppShell, and feature modules. OpenAPI-aligned hand-written models for foundation endpoints; codegen can replace models later without changing service protocols.

**Tech Stack:** Swift 6, SwiftUI, URLSession, Keychain (Security framework), XCTest, XcodeGen (`project.yml` → `Yuvomi.xcodeproj`), GitHub Actions `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-08-10-yuvomi-ios-design.md`

## Global Constraints

- Deployment target: **iOS 18.0**
- License: **MIT**; public GitHub `ajthom90/yuvomi-ios`
- No vendor backend; data only to user-configured server
- Auth: API token primary + username/password session (cookie + CSRF)
- Offline: online-first + read snapshot cache; mutations require network
- UI: native SwiftUI, Yuvomi accent families — not a PWA clone
- Minimum server: Yuvomi **2.x** (document in README)
- Do not commit secrets, provisioning profiles, or personal server URLs
- English UI first

## File map (Phase 0)

```
project.yml
.gitignore
LICENSE
README.md
CONTRIBUTING.md
SECURITY.md
.github/workflows/ci.yml
Yuvomi/
  App/
    YuvomiApp.swift
    AppDependencies.swift
    AppRootView.swift
  DesignSystem/
    YuvomiColors.swift
    ModuleKind.swift
  Core/
    Models/
      User.swift
      VersionInfo.swift
      DashboardSnapshot.swift
      APIError.swift
    Networking/
      ServerURL.swift
      HTTPClient.swift
      YuvomiAPI.swift
      AuthHeaderProviding.swift
    Auth/
      AuthCredentials.swift
      KeychainStore.swift
      AuthSessionStore.swift
      AuthService.swift
    Cache/
      ResponseCache.swift
  AppShell/
    MainTabView.swift
    ModuleDestination.swift
    ModulePlaceholderView.swift
  Features/
    Onboarding/
      WelcomeView.swift
      ServerURLView.swift
      LoginView.swift
      OnboardingFlowView.swift
    Dashboard/
      DashboardView.swift
      DashboardViewModel.swift
    Settings/
      SettingsView.swift
      SettingsViewModel.swift
YuvomiTests/
  ServerURLTests.swift
  AuthSessionStoreTests.swift
  HTTPClientAuthTests.swift
  ResponseCacheTests.swift
```

---

### Task 1: Repo skeleton, license, XcodeGen project

**Files:**
- Create: `project.yml`, `.gitignore`, `LICENSE`, `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.github/workflows/ci.yml`
- Create: minimal app entry so the project builds: `Yuvomi/App/YuvomiApp.swift`, `Yuvomi/App/AppRootView.swift`

**Interfaces:**
- Produces: Xcode project `Yuvomi.xcodeproj` with targets `Yuvomi` (iOS app) and `YuvomiTests`

- [ ] **Step 1: Write project.yml**

```yaml
name: Yuvomi
options:
  bundleIdPrefix: cloud.yuvomi
  deploymentTarget:
    iOS: "18.0"
  createIntermediateGroups: true
  developmentLanguage: en
settings:
  base:
    SWIFT_VERSION: "6.0"
    TARGETED_DEVICE_FAMILY: "1,2"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  Yuvomi:
    type: application
    platform: iOS
    sources:
      - Yuvomi
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: cloud.yuvomi.ios
        INFOPLIST_GENERATION_MODE: Generated
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Yuvomi
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsLocalNetworking: YES
        INFOPLIST_KEY_NSLocalNetworkUsageDescription: "Yuvomi can reach your home server on the local network."
        CODE_SIGN_STYLE: Automatic
    info:
      path: Yuvomi/Info.plist
      properties:
        CFBundleURLTypes:
          - CFBundleURLSchemes: [yuvomi]
            CFBundleURLName: cloud.yuvomi.ios
  YuvomiTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - YuvomiTests
    dependencies:
      - target: Yuvomi
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: cloud.yuvomi.ios.tests
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 2: Write .gitignore, MIT LICENSE, README, CONTRIBUTING, SECURITY**

README must state: community native client for self-hosted [Yuvomi](https://github.com/ulsklyc/yuvomi), MIT, how to open in Xcode, min iOS 18, min server 2.x, no cloud.

- [ ] **Step 3: Minimal SwiftUI app**

```swift
import SwiftUI

@main
struct YuvomiApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

struct AppRootView: View {
    var body: some View {
        Text("Yuvomi")
    }
}
```

- [ ] **Step 4: Generate project and build**

```bash
xcodegen generate
xcodebuild -scheme Yuvomi -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: scaffold Xcode project and open-source docs"
```

---

### Task 2: Design system — colors & module kinds

**Files:**
- Create: `Yuvomi/DesignSystem/YuvomiColors.swift`, `Yuvomi/DesignSystem/ModuleKind.swift`
- Test: `YuvomiTests/ModuleKindTests.swift`

**Interfaces:**
- Produces: `enum ModuleKind: String, CaseIterable, Identifiable` with all modules + `accent: Color`, `title: String`, `systemImage: String`, `phase: Int`
- Produces: `enum YuvomiColors` with family colors matching design tokens

- [ ] **Step 1: Write ModuleKindTests** asserting Tasks accent family is work green and all cases have non-empty titles

- [ ] **Step 2: Implement ModuleKind + YuvomiColors**

Module cases: home, tasks, shopping, calendar, meals, recipes, pantry, budget, splitExpenses, family, contacts, birthdays, health, rewards, notes, documents, housekeeping, reminders, settings

- [ ] **Step 3: Run tests**

```bash
xcodebuild -scheme Yuvomi -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:YuvomiTests/ModuleKindTests
```

- [ ] **Step 4: Commit** `feat: add Yuvomi design tokens and module registry enum`

---

### Task 3: ServerURL normalization

**Files:**
- Create: `Yuvomi/Core/Networking/ServerURL.swift`
- Test: `YuvomiTests/ServerURLTests.swift`

**Interfaces:**
- Produces: `struct ServerURL: Equatable, Sendable` with `init(raw: String) throws`, `var baseURL: URL`, `func apiURL(path: String) -> URL` where path is like `/auth/login` → `{base}/api/v1/auth/login`
- Throws `ServerURLError` for empty, non-http(s), invalid host

Rules:
- Trim whitespace
- Add `https://` if scheme missing (prefer https)
- Strip trailing slashes
- If path ends with `/api` or `/api/v1`, strip to origin root before appending `/api/v1`

- [ ] **Step 1: Write failing tests** for: `https://home.example`, `home.example` → https, strip `/api/v1`, reject `ftp://`, reject empty

- [ ] **Step 2: Implement ServerURL**

- [ ] **Step 3: Run tests — pass**

- [ ] **Step 4: Commit** `feat: normalize self-hosted server URLs`

---

### Task 4: Keychain + auth credentials store

**Files:**
- Create: `Yuvomi/Core/Auth/AuthCredentials.swift`, `KeychainStore.swift`, `AuthSessionStore.swift`
- Test: `YuvomiTests/AuthSessionStoreTests.swift` (use in-memory KeychainStore protocol fake)

**Interfaces:**

```swift
protocol SecretStore: Sendable {
    func set(_ data: Data, account: String) throws
    func get(account: String) throws -> Data?
    func delete(account: String) throws
}

enum AuthMethod: String, Codable, Sendable {
    case apiToken
    case session
}

struct ServerProfile: Codable, Equatable, Sendable {
    var serverURL: String
    var method: AuthMethod
    var displayName: String?
    var userId: Int?
}

// Session mode stores csrf + relies on HTTPCookieStorage; token mode stores token string in keychain account "token"
@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var profile: ServerProfile?
    @Published private(set) var isAuthenticated: Bool
    func saveProfile(_ profile: ServerProfile) throws
    func saveAPIToken(_ token: String) throws
    func saveCSRFToken(_ token: String) throws
    func apiToken() throws -> String?
    func csrfToken() throws -> String?
    func clearAll() throws
}
```

- [ ] **Step 1: Tests with `InMemorySecretStore`**

- [ ] **Step 2: Implement KeychainStore (kSecClassGenericPassword, service `cloud.yuvomi.ios`)**

- [ ] **Step 3: Implement AuthSessionStore**

- [ ] **Step 4: Commit** `feat: keychain-backed auth session store`

---

### Task 5: HTTP client + API error mapping

**Files:**
- Create: `Yuvomi/Core/Models/APIError.swift`, `User.swift`, `VersionInfo.swift`
- Create: `Yuvomi/Core/Networking/HTTPClient.swift`, `AuthHeaderProviding.swift`, `YuvomiAPI.swift`
- Test: `YuvomiTests/HTTPClientAuthTests.swift` with `URLProtocol` stub

**Interfaces:**

```swift
struct User: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let username: String
    let displayName: String
    let avatarColor: String
    let role: String
    let familyRole: String
    // CodingKeys: display_name, avatar_color, family_role
}

struct VersionInfo: Codable, Sendable {
    let version: String?
    let appName: String
    let setupRequired: Bool
    let passwordResetEnabled: Bool
}

struct MeResponse: Codable, Sendable {
    let user: User
    let csrfToken: String?
}

@MainActor
protocol AuthHeaderProviding: AnyObject {
    func authorize(_ request: inout URLRequest) async throws
}

final class HTTPClient: Sendable {
    init(session: URLSession = .shared, auth: AuthHeaderProviding?)
    func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T
    func sendVoid(_ request: URLRequest) async throws
}

struct YuvomiAPI {
    let client: HTTPClient
    let server: ServerURL
    func fetchVersion() async throws -> VersionInfo          // GET /api/v1/version (no auth required)
    func login(username: String, password: String) async throws -> MeResponse  // actually LoginResponse shape
    func me() async throws -> MeResponse
    func logout() async throws
    func fetchDashboard() async throws -> Data               // raw or typed later
}
```

Auth rules in `AuthSessionStore` as `AuthHeaderProviding`:
- token mode: `Authorization: Bearer <token>`
- session mode: cookies via shared cookie storage + header `X-CSRF-Token` for POST/PATCH/PUT/DELETE

- [ ] **Step 1: URLProtocol tests for Bearer injection and 401 → APIError.unauthorized**

- [ ] **Step 2: Implement models + HTTPClient + YuvomiAPI** (login POST body `{"username","password"}`, decode user + csrfToken)

- [ ] **Step 3: Wire AuthSessionStore.authorize**

- [ ] **Step 4: Commit** `feat: HTTP client and Yuvomi auth API`

---

### Task 6: Response cache

**Files:**
- Create: `Yuvomi/Core/Cache/ResponseCache.swift`
- Test: `YuvomiTests/ResponseCacheTests.swift`

**Interfaces:**

```swift
actor ResponseCache {
    init(directory: URL) // Application Support/YuvomiCache
    func store(key: String, data: Data) async throws
    func load(key: String) async -> CachedPayload? // data + savedAt
    func clearAll() async throws
    static func key(host: String, userId: Int, path: String) -> String
}
```

- [ ] **Step 1–4:** tests for store/load/clear + implement file-backed JSON sidecar with timestamp

- [ ] **Step 5: Commit** `feat: file-backed response snapshot cache`

---

### Task 7: Onboarding flow (server URL + login)

**Files:**
- Create: `Yuvomi/Features/Onboarding/*.swift`
- Modify: `AppRootView.swift`, `AppDependencies.swift`

**Interfaces:**
- `AppDependencies` owns `AuthSessionStore`, builds `YuvomiAPI` from profile
- Flow: Welcome → Server URL (validate via `GET /api/v1/version`) → Login (segment: Token | Password) → on success set profile + tokens + show shell

Token path: save token, call `me()` (or `GET /api/v1/auth/me` with Bearer).  
Password path: `login`, save csrf, ensure cookie storage is the shared one used by HTTPClient.

- [ ] **Step 1: Implement views + wire AppRootView** (`if store.isAuthenticated { MainTabView } else { OnboardingFlowView }`)

- [ ] **Step 2: Manual checklist** (document in PR): invalid URL error, version setup_required message, bad password 401

- [ ] **Step 3: Commit** `feat: onboarding connect and login flows`

---

### Task 8: App shell — tabs, More grid, placeholders

**Files:**
- Create: `Yuvomi/AppShell/*.swift`

**Interfaces:**
- Tabs: Home, Tasks, Shopping, Calendar, More
- More: LazyVGrid of `ModuleKind` excluding tab roots; Settings row
- Placeholder: title, SF Symbol, “Coming in Phase N” using `ModuleKind.phase`

- [ ] **Step 1: Implement MainTabView + placeholders**

- [ ] **Step 2: Build + smoke on simulator**

- [ ] **Step 3: Commit** `feat: main tab shell and module placeholders`

---

### Task 9: Dashboard + Settings

**Files:**
- Create: `Yuvomi/Features/Dashboard/*`, `Yuvomi/Features/Settings/*`
- Create: `Yuvomi/Core/Models/DashboardSnapshot.swift`

**Dashboard:**
- `GET /api/v1/dashboard` → decode flexibly: store raw JSON dictionary or known keys if stable; show user greeting + server version + list of top-level JSON keys/counts as interim if schema is loose; prefer decoding known optional sections (tasks, events, meals, shopping) when present as arrays.

**Settings:**
- Server URL (read-only display), signed-in user, auth method
- Clear cache button
- Sign out
- About: MIT, link to GitHub, link to upstream Yuvomi, app version from Bundle

- [ ] **Step 1: DashboardViewModel loads with cache fallback banner**

- [ ] **Step 2: SettingsViewModel clear cache + logout**

- [ ] **Step 3: Commit** `feat: dashboard and settings`

---

### Task 10: CI, GitHub remote, Phase 0 polish

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `README.md` with build status, architecture pointer to design doc

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app
      - name: Generate project
        run: brew install xcodegen && xcodegen generate
      - name: Test
        run: xcodebuild -scheme Yuvomi -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Note: CI runner images may differ from local macOS 27 / Xcode 26; adjust destination name to whatever the runner provides. Local dev uses iPhone 17 / iOS 26 sim.

- [ ] **Step 1: Create public repo `ajthom90/yuvomi-ios`, push main**

- [ ] **Step 2: Ensure `xcodegen generate && xcodebuild test` passes locally**

- [ ] **Step 3: Tag mental milestone Phase 0 complete in README status table**

- [ ] **Step 4: Commit** `chore: add CI and document Phase 0 status`

---

## Later phases (outline only — separate plans when starting)

| Phase | Plan when starting | Deliverables |
|-------|-------------------|--------------|
| 1 | `…-phase1-daily.md` | Tasks, Shopping, Calendar full core CRUD |
| 2 | `…-phase2-kitchen.md` | Meals, Recipes, Pantry + handoffs |
| 3 | `…-phase3-money.md` | Budget, Split expenses |
| 4 | `…-phase4-people.md` | Family, Contacts, Birthdays, Health, Rewards |
| 5 | `…-phase5-records.md` | Notes, Documents, Housekeeping, Reminders |
| 6 | `…-phase6-polish.md` | Admin, search, widgets, a11y, App Store |

## Spec coverage (self-review)

| Spec section | Tasks |
|--------------|-------|
| §1 Shell & product | 1, 7, 8 |
| §2 Auth & security | 4, 5, 7, 9 |
| §3 Networking & cache | 3, 5, 6, 9 |
| §4 Phase 0 only | 1–10; later phases outlined |
| §5 Repo / license / CI | 1, 10 |
| Design system | 2 |

## Environment notes (maintainer machine)

- macOS 27 beta, Xcode 26.6, iOS 26.5 SDK, iOS 26.0 simulator runtime
- Prefer destination `platform=iOS Simulator,name=iPhone 17`
- No extra SDK download required for Phase 0 if `xcodebuild build` succeeds
