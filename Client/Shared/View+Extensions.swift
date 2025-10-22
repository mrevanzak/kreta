import SwiftUI

extension View {
  /// Applies a transformation to the view if the given condition is true.
  /// - Parameters:
  ///   - condition: A boolean value that determines whether the transform is applied.
  ///   - transform: A closure that takes the view and returns a modified view.
  /// - Returns: The original view or the transformed view based on the condition.
  @ViewBuilder
  func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}
