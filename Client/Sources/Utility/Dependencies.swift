import ConvexMobile
import Foundation

final class Dependencies: @unchecked Sendable {
  static let shared = Dependencies()

  let convexClient: ConvexClient
  let telemetry: Telemetry

  init(
    convexClient: ConvexClient = ConvexClient(deploymentUrl: Constants.Convex.deploymentUrl),
    telemetry: Telemetry? = nil
  ) {
    print("🔧 Dependencies: Initializing ConvexClient with URL: \(Constants.Convex.deploymentUrl)")
    self.convexClient = convexClient
    if let telemetry {
      self.telemetry = telemetry
    } else {
      let er = SentryErrorReporter()
      let an = PostHogAnalytics()
      let client = TelemetryClient(
        errorReporter: er,
        analytics: an,
        baseContext: [
          "app_env": Constants.AppMeta.environment,
          "app_release": Constants.AppMeta.version,
        ],
        isEnabled: {
          // Future: gate via user consent flag in UserDefaults
          true
        }
      )
      self.telemetry = client
    }
  }
}
