## Kreta – iOS Client and Bun/Convex Server

A native SwiftUI iOS app for Indonesian train tracking with a Bun/Convex backend.

### Prerequisites

- Xcode 15+ (iOS 17+ for Observation; project targets iOS 26.0)
- Bun 1.2+ or Node.js 18+ (for Convex dev tooling)
- An Apple Developer setup to run on device (optional)

### Directory Layout

- Client/… — iOS app (SwiftUI, ActivityKit, WidgetKit)
- Server/convex/… — Convex functions (TypeScript)

### 1) Configure Client Environment

Create env files inside `Client/`:

```bash
# Client/.env.dev
CONVEX_URL=https://your-convex.cloud
POSTHOG_API_KEY=phc_xxx
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx

# Client/.env.prod
CONVEX_URL=https://your-convex.cloud
POSTHOG_API_KEY=phc_xxx
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
```

Generate `xcconfig` files from the envs:

```bash
./setup_client_env.sh           # Creates Client/Development.xcconfig and Client/Production.xcconfig

# Or explicitly
./setup_client_env.sh Client/.env.dev Client/Development.xcconfig
./setup_client_env.sh Client/.env.prod Client/Production.xcconfig
```

Notes:

- `CONVEX_URL` is written to `xcconfig` without the scheme (http/https removed) per project convention.
- Generated `xcconfig` files are consumed by Xcode build settings.

### 2) Open and Run the iOS App

Option A – Xcode:

1. Open `Client/kreta.xcodeproj` in Xcode.
2. Select the `kreta` scheme and an iOS Simulator/device.
3. Build & Run.

Option B – Command line build:

```bash
xcodebuild \
  -project Client/kreta.xcodeproj \
  -scheme kreta \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### 3) Run the Server (Convex)

```bash
cd Server
bun install            # or: npm/yarn/pnpm install

# Start Convex dev
npx convex dev         # launches Convex dev server

# Optional: run Bun app tasks if you add any scripts
bun run dev
```

Ensure your `CONVEX_URL` in the client points to the Convex deployment you are using.

### 4) Tests

Client tests:

```bash
xcodebuild \
  -project Client/kreta.xcodeproj \
  -scheme kreta \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

### Troubleshooting

- If envs don’t apply, re-run `./setup_client_env.sh` and clean build in Xcode.
- For missing packages, run `bun install` inside `Server/` and ensure SwiftPM resolves in Xcode.
- Verify Simulator version matches your installed runtimes.

### Security

Do not commit secrets. `Client/.gitignore` excludes `.env*` by default.
