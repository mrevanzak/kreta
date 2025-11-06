import Foundation

/// A function that matches a deep link URL to a destination if possible
struct DeepLinkParser: Sendable {
  let parse: @Sendable (URL) -> Destination?
}

extension URL {
  /// Split URL components without considering the scheme
  ///
  /// Example:
  ///
  /// for `moviecat://movies/123/gallery` this returns
  ///
  /// ```swift
  /// ["movies", "123", "gallery"]
  /// ```
  var fullComponents: [String] {
    guard let scheme else { return [] }

    // Use URLComponents to properly extract path components before query string
    guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
      // Fallback: extract path manually before query string
      let urlString = absoluteString.replacingOccurrences(of: "\(scheme)://", with: "")
      let pathString = urlString.split(separator: "?").first ?? ""
      return pathString.split(separator: "/").filter { !$0.isEmpty }.map { String($0) }
    }

    // For custom schemes like kreta://arrival, the host contains the first path component
    // For schemes like kreta://arrival/subpath, the host is "arrival" and path is "/subpath"
    var parts: [String] = []
    if let host = components.host, !host.isEmpty {
      parts.append(host)
    }
    if !components.path.isEmpty {
      parts.append(contentsOf: components.path.split(separator: "/").map { String($0) })
    }

    return parts.filter { !$0.isEmpty }
  }

  var queryParameters: [String: String]? {
    guard
      let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
      let queryItems = components.queryItems
    else { return nil }
    return queryItems.reduce(into: [String: String]()) { (result, item) in
      result[item.name] = item.value
    }
  }
}

extension DeepLinkParser {
  static func equal(to components: [String], destination: Destination) -> Self {
    .init { url in
      guard url.fullComponents == components else { return nil }
      AnalyticsEventService.shared.trackDeepLinkOpened(
        urlString: url.absoluteString,
        params: url.queryParameters ?? [:]
      )
      return destination
    }
  }

  static let arrival: Self = .init { url in
    guard
      url.fullComponents.first == "arrival",
      let stationCode = url.queryParameters?["code"],
      let stationName = url.queryParameters?["name"]
    else { return nil }

    AnalyticsEventService.shared.trackDeepLinkOpened(
      urlString: url.absoluteString,
      params: [
        "code": stationCode,
        "name": stationName,
      ]
    )
    return .fullScreen(.arrival(stationCode: stationCode, stationName: stationName))
  }

  static let tripStart: Self = .init { url in
    // Match: kreta://trip/start?trainId=...
    guard
      url.fullComponents == ["trip", "start"],
      let trainId = url.queryParameters?["trainId"]
    else { return nil }

    AnalyticsEventService.shared.trackDeepLinkOpened(
      urlString: url.absoluteString,
      params: ["trainId": trainId]
    )
    return .action(.startTrip(trainId: trainId))
  }
}
