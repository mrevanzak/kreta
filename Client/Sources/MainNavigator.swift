import SwiftUI

struct MainTabNavigator: View {
  @State var router: Router = .init(level: 0, identifierTab: nil)

  var body: some View {
    NavigationStack {
      HomeScreen()
        .navigationBarBackButtonHidden(true)
        .onOpenURL { url in
          if let destination = DeepLink.destination(from: url) {
            router.navigate(to: destination)
          }
        }
        .toolbar(.hidden)
    }
  }
}

#Preview {
  MainTabNavigator()
}
