import Foundation
import Sentry

final class SentryErrorReporter: ErrorReporting {
  static func configure(
    dsn: String?, environment: String, release: String, tracesSampleRate: Double,
    profilesSampleRate: Double
  ) {
    guard let dsn, !dsn.isEmpty else { return }
    SentrySDK.start { options in
      options.dsn = dsn
      options.environment = environment
      options.releaseName = release
      options.tracesSampleRate = NSNumber(value: tracesSampleRate)
      options.configureProfiling = {
        $0.sessionSampleRate = Float(profilesSampleRate)
        $0.lifecycle = .trace
      }
      // Record session replays for 100% of errors and 10% of sessions
      options.sessionReplay.onErrorSampleRate = 1.0
      options.sessionReplay.sessionSampleRate = 0.1
      // Enable logs to be sent to Sentry
      options.experimental.enableLogs = true
      options.beforeSend = { event in
        let newEvent = event
        newEvent.request?.headers?["Authorization"] = "[REDACTED]"
        newEvent.request?.cookies = nil
        if var data = newEvent.extra {
          for key in ["token", "auth", "email", "phone"] {
            if data.keys.contains(key) { data[key] = "[REDACTED]" }
          }
          newEvent.extra = data
        }
        return newEvent
      }
    }
  }

  func capture(error: Error, context: [String: Any]?, level: ErrorLevel) {
    SentrySDK.capture(error: error) { scope in
      self.apply(context: context, to: scope)
      scope.setLevel(self.map(level))
    }
  }

  func capture(message: String, context: [String: Any]?, level: ErrorLevel) {
    SentrySDK.capture(message: message) { scope in
      self.apply(context: context, to: scope)
      scope.setLevel(self.map(level))
    }
  }

  func setUser(id: String?, email: String?, properties: [String: Any]?) {
    let user = Sentry.User()
    if let id { user.userId = id }
    user.email = email
    if let properties { user.data = properties }
    SentrySDK.setUser(user)
  }

  func addBreadcrumb(message: String, category: String, data: [String: Any]?) {
    let crumb = Breadcrumb()
    crumb.level = .info
    crumb.type = "default"
    crumb.category = category
    crumb.message = message
    if let data { crumb.data = data }
    SentrySDK.addBreadcrumb(crumb)
  }

  func startTransaction(name: String, context: [String: Any]?) -> TelemetrySpan {
    let span = SentrySDK.startTransaction(name: name, operation: "custom")
    if let context {
      // Attach as tags when values are strings; avoid storing sensitive data
      for (k, v) in context {
        if let value = v as? String { span.setTag(value: value, key: k) }
      }
    }
    return SentrySpanWrapper(span: span)
  }

  private func apply(context: [String: Any]?, to scope: Scope) {
    guard let context else { return }
    for (k, v) in context { scope.setExtra(value: v, key: k) }
  }

  private func map(_ level: ErrorLevel) -> SentryLevel {
    switch level {
    case .debug: return .debug
    case .info: return .info
    case .warning: return .warning
    case .error: return .error
    case .fatal: return .fatal
    }
  }

  private final class SentrySpanWrapper: TelemetrySpan {
    let span: Span
    init(span: Span) { self.span = span }
    func set(tag: String, value: String) { span.setTag(value: value, key: tag) }
    func finish(status: TelemetrySpanStatus) {
      switch status {
      case .ok:
        span.finish(status: .ok)
      case .error(let message):
        span.setTag(value: message, key: "error")
        span.finish(status: .internalError)
      }
    }
  }
}
