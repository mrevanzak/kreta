import ConvexMobile
import CoreLocation
import Foundation

struct Position: Codable {
  let latitude: Double
  let longitude: Double

  func asCLLocationCoordinate2D() -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

extension StationResponse {
  func asStation() -> Station {
    return Station(
      id: id, code: code, name: name,
      position: Position(latitude: position.latitude, longitude: position.longitude), city: city)
  }
}
struct Station: Codable, Identifiable {
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
  let numericIdentifier: Int?

  init(id: String, name: String, path: [Position], numericIdentifier: Int? = nil) {
    self.id = id
    self.name = name
    self.path = path
    self.numericIdentifier = numericIdentifier

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
struct LiveTrain: Codable, Identifiable {
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

struct ProjectedTrain: Codable, Identifiable {
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
