import ActivityKit
import Foundation

public enum JourneyState: String, Codable, Hashable, Sendable {
  case beforeBoarding
  case onBoard
  case prepareToDropOff
}

public struct TrainStation: Codable, Hashable, Sendable {
  public var name: String
  public var code: String
  public var estimatedTime: Date?

  private enum CodingKeys: String, CodingKey {
    case name
    case code
    case estimatedTime
  }

  public init(name: String, code: String, estimatedTime: Date? = nil) {
    self.name = name
    self.code = code
    self.estimatedTime = estimatedTime
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    code = try container.decode(String.self, forKey: .code)

    // Decode Unix timestamps (seconds since 1970) as Dates
    if let timestamp = try container.decodeIfPresent(Double.self, forKey: .estimatedTime) {
      estimatedTime = Date(timeIntervalSince1970: timestamp)
    } else {
      estimatedTime = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(code, forKey: .code)

    // Encode Dates as Unix timestamps (seconds since 1970)
    if let time = estimatedTime {
      try container.encode(time.timeIntervalSince1970, forKey: .estimatedTime)
    } else {
      try container.encodeNil(forKey: .estimatedTime)
    }
  }
}

@available(iOS 16.1, *)
public struct TrainActivityAttributes: ActivityAttributes, Sendable {
  public struct ContentState: Codable, Hashable, Sendable {
    public var journeyState: JourneyState
    public var alarmEnabled: Bool
    public var alarmOffsetMinutes: Int

    public init(
      journeyState: JourneyState = .beforeBoarding,
      alarmEnabled: Bool = true,
      alarmOffsetMinutes: Int = 10
    ) {
      self.journeyState = journeyState
      self.alarmEnabled = alarmEnabled
      self.alarmOffsetMinutes = alarmOffsetMinutes
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
