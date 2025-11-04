import ConvexMobile
import CoreLocation
import Foundation

struct Position: Codable, Equatable {
  let latitude: Double
  let longitude: Double

  func asCLLocationCoordinate2D() -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

struct Station: Codable, Identifiable, Equatable {
  let id: String?
  let code: String
  let name: String
  let position: Position
  let city: String?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude)
  }

  init(id: String? = nil, code: String, name: String, position: Position, city: String? = nil) {
    self.id = id ?? code
    self.code = code
    self.name = name
    self.position = position
    self.city = city
  }
}

struct Train: Codable, Identifiable, Hashable {
  let id: String
  let code: String
  let name: String
}

struct RouteSegment: Codable {
  let from: Position
  let to: Position
  let distanceFromStartCm: Double
  let lengthCm: Double

  var endDistanceCm: Double {
    distanceFromStartCm + lengthCm
  }
}

struct Route: Codable, Identifiable {
  let id: String
  let name: String
  let path: [Position]
  let segments: [RouteSegment]
  let totalLengthCm: Double

  init(id: String, name: String, path: [Position]) {
    self.id = id
    self.name = name
    self.path = path

    let coordinates = path
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

      let distance = Route.distanceInCm(
        from: start.asCLLocationCoordinate2D(), to: end.asCLLocationCoordinate2D())
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

    return segments.last?.to.asCLLocationCoordinate2D()
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

struct ProjectedTrain: Codable, Identifiable, Equatable {
  let id: String
  let code: String
  let name: String
  let position: Position
  let moving: Bool
  let bearing: Double?
  let routeIdentifier: String?

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

  static func == (lhs: ProjectedTrain, rhs: ProjectedTrain) -> Bool {
    lhs.id == rhs.id && lhs.position.latitude == rhs.position.latitude
      && lhs.position.longitude == rhs.position.longitude && lhs.moving == rhs.moving
  }
}

// MARK: - Projection-friendly DTOs (Convex)

struct RoutePolyline: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let path: [Position]
}

struct JourneySegment: Codable, Sendable, Equatable {
  let fromStationId: String
  let toStationId: String
  let departure: Date
  let arrival: Date
  let routeId: String?

  init(fromStationId: String, toStationId: String, departure: Date, arrival: Date, routeId: String?)
  {
    self.fromStationId = fromStationId
    self.toStationId = toStationId
    self.departure = departure
    self.arrival = arrival
    self.routeId = routeId
  }

  private enum CodingKeys: String, CodingKey {
    case fromStationId
    case toStationId
    case departureTimeMs
    case arrivalTimeMs
    case routeId
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    fromStationId = try container.decode(String.self, forKey: .fromStationId)
    toStationId = try container.decode(String.self, forKey: .toStationId)

    // Decode milliseconds and normalize to local Date with hour:minute
    let departureMs = try container.decode(Double.self, forKey: .departureTimeMs)
    departure = Date(fromMillisecondsSinceEpoch: departureMs)

    let arrivalMs = try container.decode(Double.self, forKey: .arrivalTimeMs)
    arrival = Date(fromMillisecondsSinceEpoch: arrivalMs)

    routeId = try container.decodeIfPresent(String.self, forKey: .routeId)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(fromStationId, forKey: .fromStationId)
    try container.encode(toStationId, forKey: .toStationId)
    try container.encode(departure.timeIntervalSince1970 * 1000, forKey: .departureTimeMs)
    try container.encode(arrival.timeIntervalSince1970 * 1000, forKey: .arrivalTimeMs)
    try container.encodeIfPresent(routeId, forKey: .routeId)
  }
}

struct TrainJourney: Codable, Identifiable, Sendable {
  let id: String
  let trainId: String
  let code: String
  let name: String
  let segments: [JourneySegment]
}
