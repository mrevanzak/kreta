import ConvexMobile
import SwiftUI

@main
struct HelloMarketClientApp: App {
  @State private var convexClient = ConvexClient(deploymentUrl: Constants.Convex.deploymentUrl)

  @AppStorage("isAuthenticated") private var isAuthenticated = false

  var body: some Scene {
    WindowGroup {
      MainTabNavigator()
        .environment(\.convexClient, convexClient)
        .withMessageView()
    }
  }
}
