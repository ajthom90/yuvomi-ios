# Contributing

Thanks for helping build a native iOS client for [Yuvomi](https://github.com/ulsklyc/yuvomi).

## Prerequisites

- macOS with Xcode 16+ (Xcode 26 recommended)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A running Yuvomi **2.x** instance for manual testing (Docker is fine)

## Setup

```bash
git clone https://github.com/ajthom90/yuvomi-ios.git
cd yuvomi-ios
xcodegen generate
open Yuvomi.xcodeproj
```

## Project layout

| Path | Role |
|------|------|
| `Yuvomi/Core` | Auth, networking, cache, models |
| `Yuvomi/DesignSystem` | Colors, module registry |
| `Yuvomi/AppShell` | Tabs, placeholders, routing |
| `Yuvomi/Features/*` | Feature UI |
| `docs/superpowers/specs` | Design |
| `docs/superpowers/plans` | Implementation plans |

## Workflow

1. Open an issue or pick a labeled module/phase task.
2. Branch from `main`.
3. Prefer small PRs scoped to one module or one vertical slice.
4. Add/adjust unit tests under `YuvomiTests`.
5. Run:

```bash
xcodegen generate
xcodebuild -scheme Yuvomi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

(Adjust the simulator name to one installed on your machine.)

## Design rules

- Follow `docs/superpowers/specs/2026-08-10-yuvomi-ios-design.md`.
- Features depend on **service protocols**, not concrete HTTP types, when adding modules.
- No telemetry by default.
- Never commit tokens, server URLs with credentials, or signing material.

## Code style

- Swift 6, SwiftUI, async/await
- `@MainActor` for view models that touch UI state
- Prefer clear names over clever abstractions
