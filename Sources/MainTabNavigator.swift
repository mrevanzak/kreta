import SwiftUI

enum TabScreen: Hashable, Identifiable, CaseIterable {
  case home

  var id: TabScreen { self }
}

extension TabScreen {
  @ViewBuilder
  var label: some View {
    switch self {
    case .home:
      Label("Home", systemImage: "heart")
    }
  }

  @MainActor
  @ViewBuilder
  var destination: some View {
    switch self {
    case .home:
      NavigationStack {
        Text("Home")
      }
    }
  }
}

struct MainTabNavigator: View {
  @State var selection: TabScreen?

  var body: some View {
    TabView(selection: $selection) {
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
