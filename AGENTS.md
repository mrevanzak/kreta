# AGENTS.md: AI Collaboration Guide

This document provides essential context for AI models interacting with this project. Adhering to these guidelines will ensure consistency and maintain code quality.

## 1. Project Overview & Purpose

* **Primary Goal:** Native SwiftUI client for an e-commerce marketplace that integrates Convex-backed data, Stripe-based checkout flows, and ActivityKit live updates, paired with a lightweight Bun/Convex server stub.
* **Business Domain:** Mobile commerce and order fulfillment tooling with real-time travel status experiments (train live activity prototype).

## 2. Core Technologies & Stack

* **Languages:** Swift 5.9+ (Observation framework usage), SwiftUI; TypeScript targeting Bun runtime. No Nim components are present despite legacy references.
* **Frameworks & Runtimes:** SwiftUI, Observation, ActivityKit, WidgetKit, ConvexMobile SDK, Stripe & StripePaymentSheet, JWTDecode. Server uses Bun v1.2+ runtime with Convex cloud database/client SDK.
* **Databases:** Convex cloud database via Convex SDK; no direct SQL/NoSQL drivers in-tree.
* **Key Libraries/Dependencies:** `HTTPClient` abstraction atop `URLSession`; `ConvexMobile.ConvexClient`; `TrainLiveActivityService` & `TrainActivityAttributes` for live activities; StripePaymentSheet flows; JWTDecode for token validation; server depends on `convex` NPM package.
* **Platforms:** iOS 16.1+ (ActivityKit) and iOS 17+ (Observation) simulators/devices; WidgetKit Live Activities; Bun-compatible server environments (macOS/Linux) for Convex dev server.
* **Package Manager:** Swift Package Manager via Xcode project configuration; Bun/npm for the server package management.

## 3. Architectural Patterns

* **Overall Architecture:** Multi-target SwiftUI application organized around MVVM-inspired "stores" and networking controllers, supplemented by ActivityKit widgets; companion Bun/Convex server providing placeholder backend APIs.
* **Directory Structure Philosophy:**
  * `/Client/Sources`: Primary Swift code separated into `Controllers/`, `Stores/`, `Services/`, `Networking/`, `Screens/`, `Views/`, `Validators/`, `Models/`, `Extensions/`, `Navigation/`, `Utility/`, `Custom Errors/`, and `Preview Content/` folders mirroring logical concerns.
  * `/Client/Shared`: Cross-target models shared with the Widget extension (e.g., `TrainActivityAttributes`).
  * `/Client/Widget`: WidgetKit target for Live Activities and Dynamic Island UI.
  * `/Client/Shared`, `/Client/Widget`: Compiled as additional targets referenced by Xcode project `tututut.xcodeproj`.
  * `/Server`: Bun/TypeScript Convex backend with `index.ts`, `convex/_generated` artifacts, and sample data.
  * `buildServer.json`: Xcode build server metadata (BSP) for Swift development tooling.
* **Module Organization:** Swift code is grouped by feature role—network controllers wrap REST endpoints, stores act as `@Observable` state containers, screens/views compose UI, and services encapsulate integrations. Shared structs live in `Models/` or `Shared/`, and navigation uses dedicated router abstractions.

## 4. Coding Conventions & Style Guide

* **Formatting:** Follow Swift's standard four-space indentation and trailing space trimming. ActivityKit/Widget files occasionally use two-space indents, but prefer four spaces for new code. Keep braces on the same line per Swift conventions and run Xcode's auto-formatting.
* **Naming Conventions:**
  * Types and enums: PascalCase (`TrainLiveActivityService`, `ProductStore`).
  * Properties/functions/variables: camelCase (`loadAllProducts`, `trainLiveActivityService`).
  * Protocol/extension filenames: `Type+Category.swift` (`EnvironmentValues+Extensions.swift`).
  * Swift source files live in PascalCase grouped by feature; keep preview-only helpers in `Preview Content`.
* **API Design:**
  * **Style:** Primarily procedural with lightweight structs/enums and `@Observable` classes for state. Services expose async functions returning domain models.
  * **Abstraction:** Networking is funneled through `Resource` + `HTTPClient`; controllers convert high-level intents (login, payment) into HTTP calls; stores expose derived data/computed properties for UI binding.
  * **Extensibility:** Add new endpoints by composing `Resource` instances and extending existing stores/controllers; shared models conform to `Codable` and `Identifiable` for SwiftUI compatibility; ActivityKit attributes designed for future station states.
  * **Trade-offs:** Emphasis on developer ergonomics with async/await and SwiftUI Observation; relies on Convex and Stripe SDKs rather than manual performance tuning. Networking errors are centralized for better localization.
* **Common Patterns & Idioms:**
  * **Metaprogramming:** Minimal; relies on Swift macros like `@Observable` (compiler-provided) rather than custom templates.
  * **Memory Management:** Standard ARC with value semantics (`struct`) for models and reference types (`class`) for stores/services; ActivityKit contexts marked `Sendable`.
  * **Polymorphism:** Compile-time generics via `Resource<T>`; runtime polymorphism is rare, with simple enums and structs preferred.
  * **Type Safety:** Frequent use of `Codable`, `Identifiable`, `Hashable`, and optional handling; `@MainActor` to confine UI-affecting operations.
  * **Concurrency:** Async/await for HTTP and ActivityKit interactions; Live Activity updates iterate through `Activity` collection.
* **Error Handling:** Throwing functions propagate `NetworkError` or feature-specific error enums; controller/store methods `throw` to surface failures; UI uses `Task` with `do/catch` logging.

## 5. Key Files & Entrypoints

* **Main Entrypoint:** `Client/Sources/App.swift` declares `HelloMarketClientApp` as the `@main` SwiftUI app, injecting a `ConvexClient` and root `MainTabNavigator`.
* **Configuration:**
  * `Client/Sources/Utility/Constants.swift` centralizes REST endpoints and Convex deployment URL (controlled via `CONVEX_URL`).
  * `buildServer.json` configures the Xcode build server (BSP) for Swift toolchains.
  * No Nim configuration files exist; set environment keys via Xcode schemes.
* **CI/CD Pipeline:** No CI configurations are present; establish workflows in `.github/workflows/` if needed.

## 6. Development & Testing Workflow

* **Local Development Environment:**
  1. Open `Client/tututut.xcodeproj` in Xcode 15 or newer (iOS 17 SDK recommended for `Observation`).
  2. Provide required environment variables (e.g., `STRIPE_PUBLISHABLE_KEY`, `CONVEX_URL`, API base URLs) via the run scheme or shell before launching.
  3. Ensure backend endpoints at `http://localhost:8080` are available (either by running the Bun/Convex server or a separate API service).
  4. For command-line builds use `xcodebuild -project Client/tututut.xcodeproj -scheme tututut -destination 'platform=iOS Simulator,name=iPhone 15' build` and swap `build` with `test` when tests exist.
  5. For the server, run `bun install` then `bun run index.ts` or `npm run dev` with `npx convex dev` to start Convex.
* **Task Configuration:** Swift uses standard Xcode schemes; no `.nims` or Nimble tasks. Server relies on Bun scripts defined in `package.json`.
* **Testing:** XCTest targets are not yet checked in. Mirror source tree under a `Tests/` group when adding tests (e.g., `Stores/ProductStoreTests.swift`), and execute via Xcode or `xcodebuild test`.
* **CI/CD Process:** Not configured. Future pipelines should run Swift formatters/builds and Bun/Convex linting, then deploy Live Activity entitlements as required.

## 7. Specific Instructions for AI Collaboration

* **Contribution Guidelines:** Maintain the existing folder boundaries (`Controllers`, `Stores`, `Services`, etc.). Extend current types before introducing parallel utilities. Provide screenshots or recordings for visible UI changes, and ensure new networking flows include appropriate error handling and token management.
* **Security:** Do not commit secrets (Stripe keys, Convex deployment tokens). Keep API endpoints centralized in `Constants`. Validate JWT tokens via `TokenValidator` and prefer secure storage (`Keychain`).
* **Dependencies:** Add Swift dependencies through Xcode project settings (SPM) and mirror them in both app and widget targets as necessary. For server dependencies, update `package.json` and re-run `bun install`; commit resulting lockfiles (`bun.lock`, `yarn.lock`) consistently.
* **Commit Messages:** Use imperative, scoped subjects (e.g., `Add cart quantity badge`, `Refine HTTPClient retries`). Separate unrelated refactors from feature commits to preserve review clarity.
