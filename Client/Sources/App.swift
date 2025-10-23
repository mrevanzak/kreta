import ConvexMobile
import SwiftUI

@main
struct KretaApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var convexClient = Dependencies.shared.convexClient

  @AppStorage("isAuthenticated") private var isAuthenticated = false

  var body: some Scene {
    WindowGroup {
      MainTabNavigator()
        .environment(\.convexClient, convexClient)
        .withMessageView()
    }
  }
}
