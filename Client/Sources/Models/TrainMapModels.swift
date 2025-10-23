import CoreLocation
import Foundation

struct Position: Codable, Hashable {
  let latitude: Double
  let longitude: Double
}

struct Station: Codable, Identifiable, Hashable {
  // Use station code (e.g., "GMR") as stable identifier
  var id: String { code }
  let code: String
  let name: String
  let position: Position
  let city: String?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude)
  }
}

struct Train: Codable, Identifiable, Hashable {
  let id: String
  let name: String
}

struct Route: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  let path: [Position]

  var coordinates: [CLLocationCoordinate2D] {
    path.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
  }
}

struct LiveTrain: Codable, Identifiable, Hashable {
  let id: String
  let latitude: Double
  let longitude: Double
  let bearing: Double?
  let speedKph: Double?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
