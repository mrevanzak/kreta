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
    .equal(
      to: ["arrival"],
      destination: .fullScreen(.arrival(stationCode: "BDO", stationName: "Bandung")))
  ]
}
