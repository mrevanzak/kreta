import ConvexMobile
import CoreLocation
import Foundation

struct Position: Codable {
  @ConvexFloat
  var latitude: Double
  @ConvexFloat
  var longitude: Double
}

struct Station: Codable, Identifiable {
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

struct RouteSegment {
  let from: CLLocationCoordinate2D
  let to: CLLocationCoordinate2D
  let distanceFromStartCm: Double
  let lengthCm: Double

  var endDistanceCm: Double {
    distanceFromStartCm + lengthCm
  }
}

struct Route: Identifiable {
  let id: String
  let name: String
  let path: [Position]
  let segments: [RouteSegment]
  let totalLengthCm: Double
  let numericIdentifier: Int?

  init(id: String, name: String, path: [Position], numericIdentifier: Int? = nil) {
    self.id = id
    self.name = name
    self.path = path
    self.numericIdentifier = numericIdentifier

    let coordinates = path.map {
      CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
    }
    if coordinates.count < 2 {
      segments = []
      totalLengthCm = 0
      return
    }

    var builtSegments: [RouteSegment] = []
    var cumulativeDistance: Double = 0

    for index in 0..<(coordinates.count - 1) {
      let start = coordinates[index]
      let end = coordinates[index + 1]

      let distance = Route.distanceInCm(from: start, to: end)
      let segment = RouteSegment(
        from: start,
        to: end,
        distanceFromStartCm: cumulativeDistance,
        lengthCm: distance
      )
      cumulativeDistance += distance
      builtSegments.append(segment)
    }

    segments = builtSegments
    totalLengthCm = cumulativeDistance
  }

  var coordinates: [CLLocationCoordinate2D] {
    path.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
  }

  func coordinateAt(distanceCm: Double) -> CLLocationCoordinate2D? {
    guard let first = coordinates.first else { return nil }
    guard let lastSegment = segments.last else { return first }

    let clampedDistance = max(0, min(distanceCm, lastSegment.endDistanceCm))

    if segments.isEmpty {
      return first
    }

    for segment in segments {
      if clampedDistance >= segment.distanceFromStartCm && clampedDistance <= segment.endDistanceCm
      {
        let segmentLength = segment.lengthCm
        let progress =
          segmentLength > 0
          ? (clampedDistance - segment.distanceFromStartCm) / segmentLength
          : 0
        let latitude = Route.lerp(segment.from.latitude, segment.to.latitude, progress)
        let longitude = Route.lerp(segment.from.longitude, segment.to.longitude, progress)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      }
    }

    return segments.last?.to
  }

  private static func distanceInCm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
    -> Double
  {
    let start = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let end = CLLocation(latitude: to.latitude, longitude: to.longitude)
    return start.distance(from: end) * 100
  }

  private static func lerp(_ from: Double, _ to: Double, _ t: Double) -> Double {
    from + (to - from) * t
  }
}

extension Route: Codable {
  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case path
    case numericIdentifier
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(String.self, forKey: .id)
    let name = try container.decode(String.self, forKey: .name)
    let path = try container.decode([Position].self, forKey: .path)
    let numericIdentifier = try container.decodeIfPresent(Int.self, forKey: .numericIdentifier)
    self.init(id: id, name: name, path: path, numericIdentifier: numericIdentifier)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(path, forKey: .path)
    try container.encodeIfPresent(numericIdentifier, forKey: .numericIdentifier)
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

struct ProjectedTrain: Identifiable {
  let id: String
  let code: String
  let name: String
  let position: Position
  let moving: Bool
  let bearing: Double?

  // Optional contextual data to keep legacy UI components functional
  let speedKph: Double?
  let fromStation: Station?
  let toStation: Station?
  let segmentDeparture: Date?
  let segmentArrival: Date?
  let progress: Double?
  let journeyDeparture: Date?
  let journeyArrival: Date?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude)
  }
}
