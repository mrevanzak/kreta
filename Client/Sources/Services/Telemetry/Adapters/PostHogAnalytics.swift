import Foundation
import PostHog

final class PostHogAnalytics: AnalyticsTracking {
  static func configure(apiKey: String?, host: String, captureScreenViews: Bool) {
    guard let apiKey, !apiKey.isEmpty else { return }
    let config = PostHogConfig(apiKey: apiKey, host: host)
    config.captureScreenViews = captureScreenViews
    config.sessionReplay = false
    config.sessionReplayConfig.maskAllImages = true
    config.sessionReplayConfig.maskAllTextInputs = true
    config.sessionReplayConfig.screenshotMode = false
    PostHogSDK.shared.setup(config)
  }

  func identify(userId: String?) {
    if let userId {
      PostHogSDK.shared.identify(userId)
    } else {
      PostHogSDK.shared.reset()
    }
  }

  func screen(name: String, properties: [String: Any]?) {
    PostHogSDK.shared.screen(name, properties: properties)
  }

  func track(event: String, properties: [String: Any]?) {
    PostHogSDK.shared.capture(event, properties: properties)
  }

  func setUserProperties(_ properties: [String: Any]) {
    PostHogSDK.shared.register(properties)
  }
}
