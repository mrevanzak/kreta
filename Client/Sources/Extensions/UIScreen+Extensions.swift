import SwiftUI

@MainActor class Screen {
  static var safeArea: UIEdgeInsets = UIScreen.safeArea
  static var width: CGFloat { UIScreen.main.bounds.size.width }
  static var height: CGFloat { UIScreen.main.bounds.size.height }
}

extension UIScreen {
  fileprivate static var safeArea: UIEdgeInsets {
    UIApplication.shared
      .connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .safeAreaInsets ?? .zero
  }
}
