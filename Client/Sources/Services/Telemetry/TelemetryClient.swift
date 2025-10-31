import Foundation

final class TelemetryClient: Telemetry {
  private let errorReporter: ErrorReporting
  private let analytics: AnalyticsTracking
  private let baseContext: [String: Any]
  private let isEnabled: () -> Bool
  private let queue = DispatchQueue(label: "TelemetryClient.queue")

  init(
    errorReporter: ErrorReporting, analytics: AnalyticsTracking, baseContext: [String: Any] = [:],
    isEnabled: @escaping () -> Bool = { true }
  ) {
    self.errorReporter = errorReporter
    self.analytics = analytics
    self.baseContext = baseContext
    self.isEnabled = isEnabled
  }

  func withContext(_ additional: [String: Any]) -> Telemetry {
    var merged = baseContext
    for (k, v) in additional { merged[k] = v }
    return TelemetryClient(
      errorReporter: errorReporter, analytics: analytics, baseContext: merged, isEnabled: isEnabled)
  }

  // MARK: - ErrorReporting
  func capture(error: Error, context: [String: Any]?, level: ErrorLevel) {
    guard isEnabled() else { return }
    let payload = merged(context)
    queue.async { self.errorReporter.capture(error: error, context: payload, level: level) }
  }

  func capture(message: String, context: [String: Any]?, level: ErrorLevel) {
    guard isEnabled() else { return }
    let payload = merged(context)
    queue.async { self.errorReporter.capture(message: message, context: payload, level: level) }
  }

  func setUser(id: String?, email: String?, properties: [String: Any]?) {
    guard isEnabled() else { return }
    queue.async { self.errorReporter.setUser(id: id, email: email, properties: properties) }
  }

  func addBreadcrumb(message: String, category: String, data: [String: Any]?) {
    guard isEnabled() else { return }
    let payload = merged(data)
    queue.async {
      self.errorReporter.addBreadcrumb(message: message, category: category, data: payload)
    }
  }

  func startTransaction(name: String, context: [String: Any]?) -> TelemetrySpan {
    guard isEnabled() else { return NoopSpan() }
    let payload = merged(context)
    return errorReporter.startTransaction(name: name, context: payload)
  }

  // MARK: - AnalyticsTracking
  func identify(userId: String?) {
    guard isEnabled() else { return }
    queue.async { self.analytics.identify(userId: userId) }
  }

  func screen(name: String, properties: [String: Any]?) {
    guard isEnabled() else { return }
    let payload = merged(properties)
    queue.async { self.analytics.screen(name: name, properties: payload) }
  }

  func track(event: String, properties: [String: Any]?) {
    guard isEnabled() else { return }
    let payload = merged(properties)
    queue.async { self.analytics.track(event: event, properties: payload) }
  }

  func setUserProperties(_ properties: [String: Any]) {
    guard isEnabled() else { return }
    let payload = merged(properties)
    queue.async { self.analytics.setUserProperties(payload) }
  }

  // MARK: - Helpers
  private func merged(_ context: [String: Any]?) -> [String: Any] {
    guard let context else { return baseContext }
    var merged = baseContext
    for (k, v) in context { merged[k] = v }
    return merged
  }
}
