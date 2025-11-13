import CoreLocation
import OSLog
import UserNotifications

@MainActor
final class StationProximityNotificationService: NSObject {
  static let shared = StationProximityNotificationService()

  private let notificationCenter = UNUserNotificationCenter.current()
  private let locationManager = CLLocationManager()
  private let logger = Logger(
    subsystem: "kreta", category: String(describing: StationProximityNotificationService.self))

  private var candidateStations: [Station] = []

  private let maxTrackedStations = 10
  private let notificationIdentifierPrefix = "station_proximity_"
  private let notificationCategory = "STATION_PROMO"
  private let regionRadius: CLLocationDistance = 750

  private override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func refreshTrackedStations(_ stations: [Station]) {
    candidateStations = stations

    guard !stations.isEmpty else {
      logger.debug("No stations provided for proximity tracking")
      return
    }

    guard CLLocationManager.locationServicesEnabled() else {
      logger.error("Location services disabled; cannot schedule station proximity notifications")
      return
    }

    ensureAuthorization()
    locationManager.requestLocation()
  }

  private func ensureAuthorization() {
    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      // Request upgrade to always authorization so geofences can fire in background
      locationManager.requestAlwaysAuthorization()
    case .authorizedAlways:
      break
    case .denied, .restricted:
      logger.error("Location authorization denied or restricted; unable to monitor stations")
    @unknown default:
      logger.error("Encountered unknown location authorization state")
    }
  }

  private func handleLocationUpdate(_ location: CLLocation) {
    guard !candidateStations.isEmpty else {
      logger.debug("No candidate stations available when location updated")
      return
    }

    let nearestStations = candidateStations
      .sorted { lhs, rhs in
        let lhsLocation = CLLocation(latitude: lhs.position.latitude, longitude: lhs.position.longitude)
        let rhsLocation = CLLocation(latitude: rhs.position.latitude, longitude: rhs.position.longitude)
        return location.distance(from: lhsLocation) < location.distance(from: rhsLocation)
      }
      .prefix(maxTrackedStations)

    logger.info("Preparing \(nearestStations.count) station proximity notifications")

    Task {
      await scheduleNotifications(for: Array(nearestStations))
    }
  }

  private func scheduleNotifications(for stations: [Station]) async {
    guard !stations.isEmpty else {
      logger.debug("No stations available for notification scheduling")
      return
    }

    await removeExistingStationNotifications()

    for station in stations {
      let region = CLCircularRegion(
        center: station.coordinate,
        radius: regionRadius,
        identifier: notificationIdentifierPrefix + station.code
      )
      region.notifyOnEntry = true
      region.notifyOnExit = false

      let content = UNMutableNotificationContent()
      content.title = "Sedang di stasiun?"
      content.body = "Gunakan Kreta untuk menjadwalkan perjalanan dari Stasiun \(station.name)."
      content.sound = .default
      content.categoryIdentifier = notificationCategory
      content.interruptionLevel = .active
      content.userInfo = [
        "station_code": station.code,
        "station_name": station.name,
      ]

      let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
      let request = UNNotificationRequest(
        identifier: region.identifier,
        content: content,
        trigger: trigger
      )

      do {
        try await addNotificationRequest(request)
        logger.info("Scheduled station promotion notification for \(station.name, privacy: .public)")
      } catch {
        logger.error("Failed to schedule station notification: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private func addNotificationRequest(_ request: UNNotificationRequest) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      notificationCenter.add(request) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }

  private func removeExistingStationNotifications() async {
    let pendingRequests = await getPendingNotificationRequests()
    let identifiers = pendingRequests
      .map(\.identifier)
      .filter { $0.hasPrefix(notificationIdentifierPrefix) }

    guard !identifiers.isEmpty else { return }

    notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    logger.info("Removed \(identifiers.count) pending station proximity notifications")
  }

  private func getPendingNotificationRequests() async -> [UNNotificationRequest] {
    await withCheckedContinuation { continuation in
      notificationCenter.getPendingNotificationRequests { requests in
        continuation.resume(returning: requests)
      }
    }
  }
}

extension StationProximityNotificationService: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      let status = manager.authorizationStatus
      switch status {
      case .authorizedAlways, .authorizedWhenInUse:
        if !candidateStations.isEmpty {
          manager.requestLocation()
        }
      case .denied, .restricted:
        await removeExistingStationNotifications()
        logger.error("Location access revoked; cleared station proximity notifications")
      case .notDetermined:
        break
      @unknown default:
        logger.error("Unknown authorization change: \(status.rawValue)")
      }
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.last else { return }
    Task { @MainActor in
      handleLocationUpdate(location)
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: any Error
  ) {
    Task { @MainActor in
      logger.error("Location manager failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
