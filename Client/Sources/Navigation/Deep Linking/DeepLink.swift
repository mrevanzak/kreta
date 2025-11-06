import Foundation

struct DeepLink {
  static func destination(from url: URL) -> Destination? {
    // guard url.scheme == Config.deepLinkScheme else { return nil }

    for parser in registeredParsers {
      if let destination = parser.parse(url) {
        return destination
      }
    }

    return nil
  }

  static let registeredParsers: [DeepLinkParser] = [
    // Match arrival deep links with query parameters, e.g.:
    // kreta://arrival?code=ABC&name=Station%20Name
    .arrival,
    .tripStart,
  ]
}
