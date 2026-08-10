# Yuvomi for iOS

**Native SwiftUI client** for [Yuvomi](https://github.com/ulsklyc/yuvomi) — the self-hosted, privacy-first family planner.

Point the app at **your** server. There is no vendor cloud, no account with us, and no trackers.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![iOS 18+](https://img.shields.io/badge/iOS-18%2B-black.svg)](#requirements)
[![Yuvomi server 2.x](https://img.shields.io/badge/Yuvomi-2.x-4F4DC9.svg)](https://github.com/ulsklyc/yuvomi)

> Community open-source client. Not an official product of the Yuvomi server maintainers unless noted otherwise.

## Status

| Phase | Scope | Status |
|-------|--------|--------|
| **0 — Foundation** | Connect, auth (token + password), dashboard, shell, settings, module map | **Shipped** |
| **1 — Daily drivers** | Tasks, Shopping, Calendar (core CRUD) | **Shipped** |
| **2 — Kitchen** | Meals, Recipes, Pantry + shopping handoffs | **Shipped** |
| **3 — Money** | Budget (accounts/txns/stats), Split expenses | **Shipped** |
| 4 — People & health | Family, Contacts, Birthdays, Health, Rewards | Planned |
| 5 — Records & ops | Notes, Documents, Housekeeping, Reminders | Planned |
| 6 — Polish | Admin edges, search, widgets, App Store | Planned |

Design: [`docs/superpowers/specs/2026-08-10-yuvomi-ios-design.md`](docs/superpowers/specs/2026-08-10-yuvomi-ios-design.md)  
Phase 0 plan: [`docs/superpowers/plans/2026-08-10-yuvomi-ios-phase0.md`](docs/superpowers/plans/2026-08-10-yuvomi-ios-phase0.md)

## Requirements

- **iOS 18+**
- **Xcode** with iOS SDK (Xcode 26.x tested)
- A reachable **Yuvomi 2.x** server (HTTPS recommended)
- Auth: **API token** (preferred) or **username/password**

## Build from source

```bash
brew install xcodegen   # once
git clone https://github.com/ajthom90/yuvomi-ios.git
cd yuvomi-ios
xcodegen generate
open Yuvomi.xcodeproj
```

Select a simulator or device and Run.

```bash
xcodebuild -scheme Yuvomi \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## App Store

Source is free under the MIT License. A paid App Store build may be offered to support development; anyone can still compile this repository themselves.

## Privacy

- Data is sent only to the server URL you configure.
- Tokens and session material live in the Keychain.
- No analytics in the default open-source build.

## License

[MIT](LICENSE) — same spirit as upstream Yuvomi.

Upstream server: [ulsklyc/yuvomi](https://github.com/ulsklyc/yuvomi) (MIT).
