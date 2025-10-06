import ConvexMobile
import Foundation
import SwiftUI

extension EnvironmentValues {
  @Entry var paymentController = PaymentController(httpClient: HTTPClient())
}

extension EnvironmentValues {
  @Entry var httpClient = HTTPClient()
}

extension EnvironmentValues {
  @Entry var authenticationController = AuthenticationController(httpClient: HTTPClient())
}

struct ShowMessageAction {
  typealias Action = (String, MessageType, Double) -> Void
  let action: Action

  func callAsFunction(_ message: String, _ messageType: MessageType = .error, delay: Double = 2.0) {
    action(message, messageType, delay)
  }
}

extension EnvironmentValues {
  @Entry var showMessage: ShowMessageAction = ShowMessageAction { _, _, _ in }
}

extension EnvironmentValues {
  @Entry var uploaderDownloader = ImageUploaderDownloader(httpClient: HTTPClient())
}

extension EnvironmentValues {
  @Entry var convexClient = ConvexClient(deploymentUrl: Constants.Convex.deploymentUrl)
}
