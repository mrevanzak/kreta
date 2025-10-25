import ConvexMobile
import Foundation

final class Dependencies: @unchecked Sendable {
  static let shared = Dependencies()

  let convexClient: ConvexClient

  init(convexClient: ConvexClient = ConvexClient(deploymentUrl: Constants.Convex.deploymentUrl)) {
    print("🔧 Dependencies: Initializing ConvexClient with URL: \(Constants.Convex.deploymentUrl)")
    self.convexClient = convexClient
  }
}
