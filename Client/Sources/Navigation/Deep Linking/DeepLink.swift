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
    .equal(to: ["home"], destination: .tab(.home)),
    // Open Home and let HomeScreen handle side effects (start live activity)
    .equal(to: ["trip", "start"], destination: .tab(.home)),
  ]
}
