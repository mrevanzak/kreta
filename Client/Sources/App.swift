import ConvexMobile
import Sentry
import SwiftUI

@main
struct KretaApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var convexClient = Dependencies.shared.convexClient

  @AppStorage("isAuthenticated") private var isAuthenticated = false

  init() {
    SentrySDK.start { options in
      options.dsn =
        "https://f0814bd5550647ede47b5dc34057f554@o4510277984124928.ingest.us.sentry.io/4510277985042432"

      // Adds IP for users.
      // For more information, visit: https://docs.sentry.io/platforms/apple/data-management/data-collected/
      options.sendDefaultPii = true

      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0

      // Configure profiling. Visit https://docs.sentry.io/platforms/apple/profiling/ to learn more.
      options.configureProfiling = {
        $0.sessionSampleRate = 1.0  // We recommend adjusting this value in production.
        $0.lifecycle = .trace
      }

      // Uncomment the following lines to add more data to your events
      options.attachScreenshot = true  // This adds a screenshot to the error events
      options.attachViewHierarchy = true  // This adds the view hierarchy to the error events

      // Enable experimental logging features
      options.experimental.enableLogs = true
    }
  }

  var body: some Scene {
    WindowGroup {
      MainTabNavigator()
        .environment(\.convexClient, convexClient)
        .withToast()
    }
  }
}
