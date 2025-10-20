import Foundation

final class PushRegistrationService {
    static let shared = PushRegistrationService()

    private let tokenStorageKey = "apnsDeviceToken"
    private let lastRegistrationSignatureKey = "apnsDeviceTokenRegistrationSignature"

    private let httpClient: HTTPClient
    private let userDefaults: UserDefaults

    private init(httpClient: HTTPClient = HTTPClient(), userDefaults: UserDefaults = .standard) {
        self.httpClient = httpClient
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

        let payload = RegisterDevicePayload(token: token, platform: "ios", userId: userId)

        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        let resource = Resource(
            url: Constants.Urls.registerDevice,
            method: .post(data),
            modelType: RegisterDeviceResponse.self
        )

        var attempt = 0
        let maxAttempts = 3

        while attempt < maxAttempts {
            do {
                let response = try await httpClient.load(resource)
                if response.success {
                    userDefaults.set(signature, forKey: lastRegistrationSignatureKey)
                }
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

private struct RegisterDevicePayload: Codable {
    let token: String
    let platform: String
    let userId: String?
}
