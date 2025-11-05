import ConvexMobile
import SwiftUI

@main
struct KretaApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  @State var router: Router = .init(level: 0)
  @State private var convexClient = Dependencies.shared.convexClient

  @AppStorage("isAuthenticated") private var isAuthenticated = false

  var body: some Scene {
    WindowGroup {
      NavigationContainer(parentRouter: router) {
        HomeScreen()
          .environment(\.convexClient, convexClient)
          .withToast()
      }
    }
  }
}
