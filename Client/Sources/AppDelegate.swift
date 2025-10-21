import UIKit
@preconcurrency import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  private let notificationCenter = UNUserNotificationCenter.current()
  private let pushRegistrationService = PushRegistrationService.shared

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    notificationCenter.delegate = self

    Task {
      await requestNotificationAuthorization()
    }

    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.hexEncodedString()
    #if DEBUG
      print("APNS device token: \(token)")
    #endif
    pushRegistrationService.storeToken(token)

    Task {
      await pushRegistrationService.registerIfNeeded(userId: nil)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let userInfo = response.notification.request.content.userInfo

    guard
      let deepLinkString = userInfo["deeplink"] as? String,
      let url = URL(string: deepLinkString)
    else {
      return
    }

    await MainActor.run {
      UIApplication.shared.open(url)
    }
  }

  private func requestNotificationAuthorization() async {
    do {
      let granted = try await notificationCenter.requestAuthorization(options: [
        .alert, .badge, .sound,
      ])

      guard granted else { return }

      await MainActor.run {
        UIApplication.shared.registerForRemoteNotifications()
      }
    } catch {
      print("Unable to request notification authorization: \(error.localizedDescription)")
    }
  }
}
