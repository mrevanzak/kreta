# Repository Guidelines

## Project Structure & Module Organization
All app code lives in `Sources/`. `App.swift` wires SwiftUI stores and Stripe configuration. Use the existing folders as boundaries: `Controllers/` for networking orchestration, `Stores/` for observable state, `Networking/` for the shared `HTTPClient`, `Services/` for integrations like `ImageUploaderDownloader`, and `Screens/` versus `Views/` for full scenes and reusable components. Keep preview data inside `Preview Content/` and assets in `Assets.xcassets/`. When adding utilities, prefer extending what exists to avoid new parallel folders (e.g., reconcile work between `Utility/` and `Utilities/`).

## Build, Test, and Development Commands
Open the app with Xcode 15+ via `open tututut.xcodeproj`. Headless builds use `xcodebuild -project tututut.xcodeproj -scheme tututut -destination 'platform=iOS Simulator,name=iPhone 15' build`. Swap `build` for `test` to execute the suite once tests exist. Before running, provide `STRIPE_PUBLISHABLE_KEY` through the scheme or shell and ensure the API at `http://localhost:8080` is reachable.

## Coding Style & Naming Conventions
Follow Swift 5 defaults with four-space indentation and type declarations in PascalCase, members in camelCase. Keep business constants in `Constants` namespaces and surface fixtures through static helpers (as in `AuthenticationController.development`). Prefer `async`/`await`, place shared errors in `Custom Errors/`, and run Xcode's "Re-indent" plus "Trim trailing whitespace" to match the current formatting. Include focused `// MARK:` sections only when they improve navigation.

## Testing Guidelines
Introduce XCTest targets that mirror the source tree (for example, `Stores/CartStoreTests.swift`). Name classes after the subject (`CartStoreTests`) and functions with the `test_action_expectedResult` convention. Favor async test functions for networking stores and inject fakes from `Services/` or `Networking/` rather than touching live endpoints. Run `xcodebuild test ...` locally or in CI before requesting review and capture simulator screenshots when UI behaviour changes.

## Commit & Pull Request Guidelines
Write commits in imperative mood with scoped titles such as `Add cart quantity badge` or `Refine HTTPClient retries`, and keep unrelated refactors separate. Pull requests should include a concise summary, manual verification notes (devices, API responses), links to tracking issues, and screenshots or screen recordings for UI updates. Request reviews from the owners of the affected folders and wait for at least one approval before merging.

## Security & Configuration Tips
Never commit secrets. Supply Stripe keys and similar credentials through scheme environment variables or future `.xcconfig` files. Update API endpoints centrally in `Sources/Utility/Constants.swift` when switching environments, and record any non-localhost backend requirements in the pull request.
