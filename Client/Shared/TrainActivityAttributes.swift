import ActivityKit
import Foundation

public struct TrainStation: Codable, Hashable, Sendable {
  public var name: String
  public var code: String
  public var estimatedArrival: Date?
  public var estimatedDeparture: Date?

  enum CodingKeys: String, CodingKey {
    case name
    case code
    case estimatedArrival
    case estimatedDeparture
  }

  public init(name: String, code: String, estimatedArrival: Date?, estimatedDeparture: Date?) {
    self.name = name
    self.code = code
    self.estimatedArrival = estimatedArrival
    self.estimatedDeparture = estimatedDeparture
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    code = try container.decode(String.self, forKey: .code)

    // Decode Unix timestamps (seconds since 1970) as Dates
    if let timestamp = try container.decodeIfPresent(Double.self, forKey: .estimatedArrival) {
      estimatedArrival = Date(timeIntervalSince1970: timestamp)
    } else {
      estimatedArrival = nil
    }

    if let timestamp = try container.decodeIfPresent(Double.self, forKey: .estimatedDeparture) {
      estimatedDeparture = Date(timeIntervalSince1970: timestamp)
    } else {
      estimatedDeparture = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(code, forKey: .code)

    // Encode Dates as Unix timestamps (seconds since 1970)
    if let arrival = estimatedArrival {
      try container.encode(arrival.timeIntervalSince1970, forKey: .estimatedArrival)
    } else {
      try container.encodeNil(forKey: .estimatedArrival)
    }

    if let departure = estimatedDeparture {
      try container.encode(departure.timeIntervalSince1970, forKey: .estimatedDeparture)
    } else {
      try container.encodeNil(forKey: .estimatedDeparture)
    }
  }
}

public struct AdjacentStations: Codable, Hashable, Sendable {
  public var previous: TrainStation
  public var next: TrainStation
}

@available(iOS 16.1, *)
public struct TrainActivityAttributes: ActivityAttributes, Sendable {
  public struct ContentState: Codable, Hashable, Sendable {
    public var stations: AdjacentStations

    public init(previousStation: TrainStation, nextStation: TrainStation) {
      self.stations = AdjacentStations(previous: previousStation, next: nextStation)
    }
  }

  public var trainName: String
  public var from: TrainStation
  public var destination: TrainStation

  public var seatClass: SeatClass
  public var seatNumber: String
}

public enum SeatClass: Codable, Hashable, Sendable {
  case economy(number: Int)
  case business(number: Int)
  case executive(number: Int)

  public var number: Int {
    switch self {
    case .economy(let number):
      return number
    case .business(let number):
      return number
    case .executive(let number):
      return number
    }
  }

  public var name: String {
    switch self {
    case .economy:
      return "Eko"
    case .business:
      return "Bis"
    case .executive:
      return "Ekse"
    }
  }
}
