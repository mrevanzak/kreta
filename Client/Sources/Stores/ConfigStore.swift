import Combine
import ConvexMobile
import Foundation
import OSLog
import Observation
import UserNotifications

struct AppConfig: Codable {
  let tripReminder: Double
  let arrivalAlert: Double
}

@MainActor
@Observable
final class ConfigStore {
  static let shared = ConfigStore()

  private nonisolated(unsafe) let convexClient = Dependencies.shared.convexClient
  @ObservationIgnored private var appConfigCancellable: AnyCancellable?

  var appConfig: AppConfig?

  let logger = Logger(subsystem: "kreta", category: String(describing: ConfigStore.self))

  init() {
    appConfigCancellable = convexClient.subscribe(
      to: "appConfig:get", yielding: AppConfig.self,
      captureTelemetry: true
    )
    .receive(on: DispatchQueue.main)
    .sink(
      receiveCompletion: { completion in
        switch completion {
        case .finished:
          self.logger.debug("AppConfig subscription completed")
        case .failure(let error):
          self.logger.error("AppConfig subscription error: \(error)")
        }
      },
      receiveValue: { appConfig in
        self.logger.debug("Received appConfig: \(String(describing: appConfig))")
        self.appConfig = appConfig
      })
  }

}
