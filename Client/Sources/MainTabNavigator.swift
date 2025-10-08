import SwiftUI

struct MainTabNavigator: View {
  @State var router: Router = .init(level: 0, identifierTab: nil)

  var body: some View {
    TabView(selection: $router.selectedTab) {
      ForEach(TabScreen.allCases) { screen in
        screen.destination
          .tag(screen as TabScreen?)
          .tabItem { screen.label }
      }
    }.navigationBarBackButtonHidden(true)
  }
}

#Preview {
  MainTabNavigator()
}
