import Foundation

protocol ErrorReporting {
  func capture(error: Error, context: [String: Any]?, level: ErrorLevel)
  func capture(message: String, context: [String: Any]?, level: ErrorLevel)
  func setUser(id: String?, email: String?, properties: [String: Any]?)
  func addBreadcrumb(message: String, category: String, data: [String: Any]?)
  func startTransaction(name: String, context: [String: Any]?) -> TelemetrySpan
}

enum ErrorLevel {
  case debug
  case info
  case warning
  case error
  case fatal
}

protocol TelemetrySpan {
  func set(tag: String, value: String)
  func finish(status: TelemetrySpanStatus)
}

enum TelemetrySpanStatus {
  case ok
  case error(String)
}

protocol AnalyticsTracking {
  func identify(userId: String?)
  func screen(name: String, properties: [String: Any]?)
  func track(event: String, properties: [String: Any]?)
  func setUserProperties(_ properties: [String: Any])
}

protocol Telemetry: ErrorReporting, AnalyticsTracking {
  func withContext(_ additional: [String: Any]) -> Telemetry
}

final class NoopSpan: TelemetrySpan {
  func set(tag: String, value: String) {}
  func finish(status: TelemetrySpanStatus) {}
}
