import ActivityKit
import Foundation

public struct TrainStation: Codable, Hashable, Sendable {
  public var name: String
  public var code: String
  public var estimatedArrival: Date?
  public var estimatedDeparture: Date?
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
