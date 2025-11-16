import AlarmKit
import CoreLocation
import Foundation
import OSLog
import UIKit
import UserNotifications

/// Service for requesting app permissions from UI
@MainActor
final class PermissionRequestService {
  static let shared = PermissionRequestService()

  private let notificationCenter = UNUserNotificationCenter.current()
  private let locationManager = CLLocationManager()
  private let logger = Logger(subsystem: "kreta", category: "PermissionRequestService")

  private init() {
    locationManager.delegate = nil  // We'll handle authorization without delegate
  }

  // MARK: - Notification Permission

  /// Get current notification permission status
  func getNotificationStatus() async -> UNAuthorizationStatus {
    let settings = await notificationCenter.notificationSettings()
    return settings.authorizationStatus
  }

  /// Request notification permission
  /// - Returns: true if granted, false otherwise
  func requestNotificationPermission() async -> Bool {
    let currentStatus = await getNotificationStatus()

    switch currentStatus {
    case .notDetermined:
      logger.info("Requesting notification authorization")

      do {
        let granted = try await notificationCenter.requestAuthorization(options: [
          .alert, .badge, .sound,
        ])

        if granted {
          await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
          }
          logger.info("Notification permission granted")
        } else {
          logger.info("Notification permission denied")
        }

        return granted
      } catch {
        logger.error("Error requesting notification authorization: \(error.localizedDescription)")
        return false
      }

    case .authorized, .provisional, .ephemeral:
      logger.info("Notification permission already granted")
      return true

    case .denied:
      logger.warning("Notification permission was previously denied")
      return false

    @unknown default:
      logger.warning("Unknown notification authorization status")
      return false
    }
  }

  // MARK: - Alarm Permission

  /// Get current alarm permission status
  nonisolated func getAlarmStatus() -> AlarmManager.AuthorizationState {
    AlarmManager.shared.authorizationState
  }

  /// Request alarm permission
  /// - Returns: true if granted, false otherwise
  func requestAlarmPermission() async -> Bool {
    let alarmManager = AlarmManager.shared
    let currentState = alarmManager.authorizationState
    logger.info("AlarmKit authorization state: \(String(describing: currentState))")

    switch currentState {
    case .notDetermined:
      logger.info("Requesting AlarmKit authorization")

      do {
        let state = try await alarmManager.requestAuthorization()
        let granted = state == .authorized
        logger.info("AlarmKit authorization result: \(String(describing: state))")
        return granted
      } catch {
        logger.error("Error requesting AlarmKit authorization: \(error.localizedDescription)")
        return false
      }

    case .authorized:
      logger.info("AlarmKit permission already granted")
      return true

    case .denied:
      logger.warning("AlarmKit permission was previously denied")
      return false

    @unknown default:
      logger.warning("Unknown AlarmKit authorization state: \(String(describing: currentState))")
      return false
    }
  }

  // MARK: - Location Permission

  /// Get current location permission status
  func getLocationStatus() -> CLAuthorizationStatus {
    locationManager.authorizationStatus
  }

  /// Request location permission
  /// - Returns: true if granted (when in use or always), false otherwise
  func requestLocationPermission() async -> Bool {
    let status = locationManager.authorizationStatus

    switch status {
    case .notDetermined:
      logger.info("Requesting location authorization")
      locationManager.requestWhenInUseAuthorization()

      // Wait a bit for the authorization to be processed
      // Note: This is a limitation - we can't await the actual result
      // The status will be updated via locationManagerDidChangeAuthorization
      try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

      let newStatus = locationManager.authorizationStatus
      let granted = newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways
      logger.info("Location authorization result: \(String(describing: newStatus))")
      return granted

    case .authorizedWhenInUse, .authorizedAlways:
      logger.info("Location permission already granted")
      return true

    case .denied, .restricted:
      logger.warning("Location permission was previously denied or restricted")
      return false

    @unknown default:
      logger.warning("Unknown location authorization status")
      return false
    }
  }
}
