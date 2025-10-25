import ConvexMobile
import CoreLocation
import Foundation

struct Position: Decodable {
  @ConvexFloat
  var latitude: Double
  @ConvexFloat
  var longitude: Double
}

struct Station: Decodable, Identifiable {
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

struct Route: Decodable, Identifiable {
  let id: String
  let name: String
  let path: [Position]

  var coordinates: [CLLocationCoordinate2D] {
    path.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
  }
}

struct LiveTrain: Decodable, Identifiable {
  let id: String
  let code: String
  let name: String

  let position: Position
  let bearing: Double?
  let speedKph: Double?

  // Current segment context
  let fromStation: Station
  let toStation: Station
  let segmentDeparture: Date
  let segmentArrival: Date
  let progress: Double

  // Whole journey context
  let journeyDeparture: Date
  let journeyArrival: Date

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude)
  }
}
