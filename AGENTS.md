# AGENTS.md: AI Collaboration Guide

This document provides essential context for AI models interacting with this project. Adhering to these guidelines will ensure consistency and maintain code quality.

AI collaborators should operate as expert Swift and SwiftUI developers, using this guide as the single source of truth for project standards.

## 1. Project Overview & Purpose

- **Primary Goal:** Native SwiftUI iOS application for Indonesian train tracking with real-time position projection, featuring Convex-backed data, ActivityKit live updates, and a Bun/Convex server backend.
- **Business Domain:** Public transportation tracking and monitoring, specifically Indonesian railway system (Kereta Api) with station connections, journey planning, and live train position updates.

## 2. Core Technologies & Stack

- **Languages:** Swift 5.9+ with Observation framework; TypeScript for Bun runtime backend.
- **Client Frameworks:** SwiftUI, Observation (macros), ActivityKit, WidgetKit, ConvexMobile SDK, MapKit, CoreLocation.
- **Backend:** Bun v1.2+ runtime with Convex cloud database (queries, mutations, subscriptions).
- **Key Dependencies:**
  - **Client:** `ConvexMobile` for real-time queries/subscriptions, `Sentry` for error reporting, `PostHog` for analytics, `Disk` for file caching, `DebugSwift` for debugging
  - **Backend:** `convex` NPM package for database operations, `@parse/node-apn` for push notifications
  - **Development:** MijickCalendarView, MijickPopups for UI components
- **Architecture:** MVVM-inspired with `@Observable` stores, service layer for business logic, HTTPClient for REST APIs, ConvexClient for real-time subscriptions.
- **Platforms:** iOS 16.1+ (ActivityKit), iOS 17+ (Observation), WidgetKit Live Activities; Bun-compatible server environments.
- **Package Manager:** Swift Package Manager via Xcode; Bun for server.

## 3. Architectural Patterns

- **Overall Architecture:** Multi-target SwiftUI application organized around MVVM-inspired stores and services, with ActivityKit widgets for Live Activities. Bun/Convex server provides real-time backend.
- **Directory Structure:**
  - `/Client/Sources`: Swift code organized by role
    - `Stores/`: `@Observable` state management (`TrainMapStore`, `ProductStore`, `CartStore`, `OrderStore`, `FeedbackStore`, `UserStore`)
    - `Services/`: Business logic (train tracking, stations, caching, telemetry, push)
    - `View Models/`: Feature-specific logic (`AddTrainViewModel`)
    - `Screens/`: Full-screen views (HomeScreen, LoginScreen, CartScreen, etc.)
    - `Views/`: Reusable components and feature views (`TrainMapView`, `AddTrainView`, etc.)
    - `Controllers/`: Authentication, Payment orchestration
    - `Networking/`: HTTPClient abstraction
    - `Models/`: DTOs and domain models
    - `Navigation/`: Router, deep linking, navigation containers
    - `Utility/`: Constants, Dependencies, Keychain, helpers
    - `Extensions/`: Type extensions
    - `Custom Errors/`: Domain error types
  - `/Client/Shared`: Cross-target code (`TrainActivityAttributes`, colors, view extensions)
  - `/Client/Widget`: WidgetKit Live Activities extension
  - `/Server/convex/`: Convex functions (queries, mutations, actions)
- **Module Organization:** Stores manage state; services handle business logic; view models contain UI-specific logic; screens compose flows; views handle presentation.

## 4. Coding Conventions & Style Guide

- **Architecture & Structure:** Adopt Swift's latest language and framework capabilities, preserve the MVVM-inspired layering used across the app, prefer value semantics (`struct`) when practical, and ensure UI decisions track Apple's Human Interface Guidelines.
- **Formatting:** Follow Swift's standard four-space indentation and trailing space trimming. ActivityKit/Widget files occasionally use two-space indents, but prefer four spaces for new code. Keep braces on the same line per Swift conventions and run Xcode's auto-formatting.
- **Naming Conventions:**
  - Types and enums: PascalCase (`TrainLiveActivityService`, `ProductStore`).
  - Properties/functions/variables: camelCase (`loadAllProducts`, `trainLiveActivityService`).
  - Protocol/extension filenames: `Type+Category.swift` (`EnvironmentValues+Extensions.swift`).
  - Swift source files live in PascalCase grouped by feature; keep preview-only helpers in `Preview Content`.
  - Use imperative verb phrases for methods (`fetchProducts`, `loadCart`).
  - Prefix boolean flags with `is`/`has`/`should` and keep names descriptive per Apple style guides.
- **Swift Language Practices:** Leverage the strong type system and intentional optional handling, prefer `let` over `var` unless mutation is required, use `async`/`await` for concurrency, and model recoverable failures with `Result` where it improves clarity.
- **State Management:** Favor Observation's `@Observable` models alongside SwiftUI property wrappers (`@State`, `@StateObject`, `@Bindable`) or `@Published` for legacy compatibility, and use protocol extensions for shared behavior.
- **API Design:**
  - **Style:** Primarily procedural with lightweight structs/enums and `@Observable` classes for state. Services expose async functions returning domain models.
  - **Abstraction:** Networking is funneled through `Resource` + `HTTPClient`; controllers convert high-level intents (login, payment) into HTTP calls; stores expose derived data/computed properties for UI binding.
  - **Extensibility:** Add new endpoints by composing `Resource` instances and extending existing stores/controllers; shared models conform to `Codable` and `Identifiable` for SwiftUI compatibility; ActivityKit attributes designed for future station states.
  - **Trade-offs:** Emphasis on developer ergonomics with async/await and SwiftUI Observation; relies on Convex and Stripe SDKs rather than manual performance tuning. Networking errors are centralized for better localization.
- **UI Development:** Default to SwiftUI views, reach for UIKit only when platform APIs demand it, use SF Symbols for glyphs, support dark mode and Dynamic Type, respect the safe area, and test layouts across device classes and orientations. Handle keyboard transitions gracefully.
- **Performance:** Profile critical paths with Instruments, lazy load expensive subviews or assets, coalesce network activity, manage background tasks responsibly, and guard against redundant state updates to avoid memory churn.
- **Data & Reactive Flow:** Use Core Data for richer on-device models when needed, keep lightweight preferences in `UserDefaults`, integrate Combine or Observation publishers for reactive flows, and design dependency injection that keeps data flow explicit and testable.
- **Common Patterns & Idioms:**
  - **Metaprogramming:** Minimal; relies on Swift macros like `@Observable` (compiler-provided) rather than custom templates.
  - **Memory Management:** Standard ARC with value semantics (`struct`) for models and reference types (`class`) for stores/services; ActivityKit contexts marked `Sendable`.
  - **Polymorphism:** Compile-time generics via `Resource<T>`; runtime polymorphism is rare, with simple enums and structs preferred.
  - **Type Safety:** Frequent use of `Codable`, `Identifiable`, `Hashable`, and optional handling; `@MainActor` to confine UI-affecting operations.
  - **Concurrency:** Async/await for HTTP and ActivityKit interactions; Live Activity updates iterate through `Activity` collection.
  - **Error Handling:** Throwing functions propagate `NetworkError` or feature-specific error enums; controller/store methods `throw` to surface failures; UI uses `Task` with `do/catch` logging.

## 5. Key Files & Entrypoints

- **Main Entrypoint:** `Client/Sources/App.swift` declares `KretaApp` as the `@main` SwiftUI app with `ConvexClient` and `MainTabNavigator`.
- **Configuration:**
  - `Client/Sources/Utility/Constants.swift`: API endpoints, Convex URL, PostHog, Sentry keys (via environment vars).
  - `Client/Sources/Utility/Dependencies.swift`: Shared singletons (`ConvexClient`, `Telemetry`).
  - `Client/Sources/Utility/KeychainWrapper.swift`: Secure token storage.
  - `Server/convex/schema.ts`: Database schema.
  - `buildServer.json`: Xcode build server metadata.
- **Core Services:**
  - `TrainMapStore`: Map state, stations, routes, projection.
  - `JourneyService`: Journey fetching from Convex.
  - `TrainLiveActivityService`: ActivityKit management.
  - `TrainMapCacheService`: On-device caching.
- **CI/CD Pipeline:** None configured; create `.github/workflows/` if needed.

## 6. Development & Testing Workflow

- **Local Development:**
  1. Open `Client/kreta.xcodeproj` in Xcode 15+ (iOS 17+ for Observation).
  2. Set environment vars in the run scheme: `CONVEX_URL`, `POSTHOG_API_KEY`, `SENTRY_DSN` (optional).
  3. For the server, run `bun install`, then `bun run dev` or `npx convex dev`.
  4. Command-line: `xcodebuild -project Client/kreta.xcodeproj -scheme kreta -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.
- **Testing:**
  - XCTest for unit tests.
  - Tests in `/Client/kretaTests` and `/Client/Tests`.
  - Existing: `AddTrainViewModelTests`.
- **Quality:**
  - Test user flows, error states, performance, accessibility.
  - Telemetry reports crashes and analytics.
  - Use Instruments for profiling.
- **CI/CD:** None configured. Add `.github/workflows` for builds/tests.

## 7. Specific Instructions for AI Collaboration

- **Contributions:**
  - Respect folder boundaries (e.g., `Stores/`, `Services/`, `Screens/`, `Views/`).
  - Extend existing types before adding duplicates.
  - Provide screenshots for UI changes.
  - Include error handling and token management in networking.
- **Security:**
  - Never commit secrets (Convex URLs, PostHog keys, Sentry DSN).
  - Centralize endpoints in `Constants.swift`.
  - Use `KeychainWrapper` for sensitive data.
  - Validate inputs; honor App Transport Security.
- **Dependencies:**
  - Add SPM in Xcode settings.
  - Mirror app and widget targets.
  - Server: update `package.json`, run `bun install`, commit `bun.lock`.
- **Commits:** Imperative, scoped subjects (e.g., `Add train journey caching`). Separate refactors from features.
- **Features:** Plan deep linking, push, background work, localization, error handling, analytics.
- **Tooling:** Use SwiftUI previews, instruments, and telemetry. Keep docs current.
- **App Store:** Declare entitlements and privacy strings; follow HIG; audit signing.

### Store Error Handling Pattern

To keep stores UI-agnostic and consistent across the app, follow this pattern:

- Stores should expose async throwing methods and avoid keeping UI-facing error state.
- Do NOT add `errorMessage` to stores. Keep ephemeral flags like `isLoading` when useful for UI; reset them using `defer`.
- Call sites (screens/views) should `do/try/await` and handle failures with the `showMessage` environment action.

Example usage at the call site:

```swift
do {
    try await store.loadInitial()
} catch {
    showMessage(error.localizedDescription)
}
```

Benefits:

- Errors are surfaced where user feedback is decided, keeping stores free of presentation concerns.
- Consistent user messaging via `Environment(\.showMessage)`.
- Easier testing of stores (deterministic, no UI coupling).
