import ActivityKit
import Foundation

public struct TrainStation: Codable, Hashable, Sendable {
  public var name: String
  public var code: String
  public var estimatedArrival: Date?
  public var estimatedDeparture: Date?
}

public struct Train: Codable, Hashable, Sendable {
  public var name: String
  public var code: String
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

  public var train: Train
  public var from: TrainStation
  public var destination: TrainStation

  public init(with train: Train, from: TrainStation, destination: TrainStation) {
    self.train = train
    self.from = from
    self.destination = destination
  }
}
