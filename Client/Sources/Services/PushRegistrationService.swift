import ConvexMobile
import Foundation

final class PushRegistrationService: @unchecked Sendable {
  static let shared = PushRegistrationService()

  private let tokenStorageKey = "apnsDeviceToken"
  private let lastRegistrationSignatureKey = "apnsDeviceTokenRegistrationSignature"

  private let convexClient: ConvexClient
  private let userDefaults: UserDefaults

  private init(
    convexClient: ConvexClient = Dependencies.shared.convexClient,
    userDefaults: UserDefaults = .standard
  ) {
    self.convexClient = convexClient
    self.userDefaults = userDefaults
  }

  func storeToken(_ token: String) {
    guard currentToken() != token else { return }
    Keychain.set(token, forKey: tokenStorageKey)
    userDefaults.removeObject(forKey: lastRegistrationSignatureKey)
  }

  func currentToken() -> String? {
    Keychain<String>.get(tokenStorageKey)
  }

  func registerIfNeeded(userId: String?) async {
    guard let token = currentToken() else { return }

    let signature = registrationSignature(token: token, userId: userId)
    if userDefaults.string(forKey: lastRegistrationSignatureKey) == signature {
      return
    }

    var attempt = 0
    let maxAttempts = 3

    while attempt < maxAttempts {
      do {
        _ = try await convexClient.mutation(
          "registrations:registerDevice",
          with: [
            "token": token,
            "userId": userId,
          ])

        // Assume success if no error is thrown
        userDefaults.set(signature, forKey: lastRegistrationSignatureKey)
        return
      } catch {
        attempt += 1
        if attempt >= maxAttempts {
          return
        }

        let delay = UInt64(pow(2.0, Double(attempt)) * 0.5 * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
      }
    }
  }

  private func registrationSignature(token: String, userId: String?) -> String {
    if let userId, !userId.isEmpty {
      return "\(token)|\(userId)"
    }

    return token
  }
}
