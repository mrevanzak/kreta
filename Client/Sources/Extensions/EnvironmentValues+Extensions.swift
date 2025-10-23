import ConvexMobile
import Foundation
import OSLog
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
    let logger = Logger(subsystem: "kreta", category: "Toast Message")
    switch messageType {
    case .error:
      logger.error("Showing error toast message: \(message)")
    case .info:
      logger.info("Showing info toast message: \(message)")
    case .success:
      logger.debug("Showing success toast message: \(message)")
    }
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
  @Entry var convexClient = Dependencies.shared.convexClient
}
