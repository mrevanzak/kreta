import Foundation
import SwiftUI

struct WithMessageView: ViewModifier {
  @State private var messageWrapper: MessageWrapper?

  func body(content: Content) -> some View {
    content
      .environment(
        \.showMessage,
        ShowMessageAction(action: { message, messageType, delay in
          self.messageWrapper = MessageWrapper(
            message: message, delay: delay, messageType: messageType)
          if messageType == .error {
            Dependencies.shared.telemetry.addBreadcrumb(
              message: "User-visible error",
              category: "ui.error",
              data: [
                "message": message
              ]
            )
          }
        })
      )
      .overlay(alignment: .bottom) {
        messageWrapper != nil ? MessageView(messageWrapper: $messageWrapper) : nil
      }
  }
}

extension View {
  func withMessageView() -> some View {
    modifier(WithMessageView())
  }
}
