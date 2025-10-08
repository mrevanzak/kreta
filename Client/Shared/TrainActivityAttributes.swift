#if canImport(ActivityKit) && os(iOS)
  import ActivityKit
  import Foundation

  @available(iOS 16.1, *)
  public struct TrainActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
      public var nextStation: String
      public var estimatedArrival: Date

      public init(nextStation: String, estimatedArrival: Date) {
        self.nextStation = nextStation
        self.estimatedArrival = estimatedArrival
      }
    }

    public var from: String
    public var destination: String

    public init(from: String, destination: String) {
      self.from = from
      self.destination = destination
    }
  }
#endif
