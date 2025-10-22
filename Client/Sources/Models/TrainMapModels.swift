import CoreLocation
import Foundation

struct Station: Codable, Identifiable, Hashable {
  // Use station code (e.g., "GMR") as stable identifier
  var id: String { code }
  let code: String
  let name: String
  let latitude: Double
  let longitude: Double

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

struct TrainPosition: Codable, Identifiable, Hashable {
  let id: String
  let latitude: Double
  let longitude: Double
  let bearing: Double?
  let speedKph: Double?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

struct TrainLine: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  // A polyline path expressed as [latitude, longitude] pairs
  let path: [[Double]]

  var coordinates: [CLLocationCoordinate2D] {
    path.compactMap { pair in
      guard pair.count == 2 else { return nil }
      return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
    }
  }
}
