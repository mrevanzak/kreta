import Foundation
import SwiftUI

enum Destination: Hashable {
  // TODO: Add other destinations here
  case push(_ destination: PushDestination)
  case sheet(_ destination: SheetDestination)
  case fullScreen(_ destination: FullScreenDestination)
  case action(_ action: ActionDestination)
}

extension Destination: CustomStringConvertible {
  var description: String {
    switch self {
    case let .push(destination): ".push(\(destination))"
    case let .sheet(destination): ".sheet(\(destination))"
    case let .fullScreen(destination): ".fullScreen(\(destination))"
    case let .action(action): ".action(\(action))"
    }
  }
}

enum PushDestination: Hashable, CustomStringConvertible {
  case home

  var description: String {
    switch self {
    case .home: ".home"
    }
  }
}

enum SheetDestination: Hashable, CustomStringConvertible {
  case feedback
  case addTrain

  var description: String {
    switch self {
    case .feedback: ".feedback"
    case .addTrain: ".addTrain"
    }
  }
}

extension SheetDestination: Identifiable {
  var id: String {
    switch self {
    case .feedback: "feedback"
    case .addTrain: "addTrain"
    }
  }
}

enum FullScreenDestination: Hashable {
  case arrival(stationCode: String, stationName: String)
}

extension FullScreenDestination: CustomStringConvertible {
  var description: String {
    switch self {
    case let .arrival(stationCode, stationName): ".arrival(\(stationCode), \(stationName))"
    }
  }
}

extension FullScreenDestination: Identifiable {
  var id: String {
    switch self {
    case let .arrival(stationCode, stationName): "\(stationCode)-\(stationName)"
    }
  }
}

// MARK: - Action destinations (no UI presentation)

enum ActionDestination: Hashable {
  case startTrip(trainId: String)
}

extension ActionDestination: CustomStringConvertible {
  var description: String {
    switch self {
    case let .startTrip(trainId): ".startTrip(\(trainId))"
    }
  }
}
