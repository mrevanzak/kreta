//
//  Errors.swift
//  hello-market-client
//
//  Created by Mohammad Azam on 9/6/24.
//

import Foundation

enum LoginError: LocalizedError {
  case loginFailed(String)

  var errorDescription: String? {
    switch self {
    case .loginFailed:
      return NSLocalizedString(
        "Login failed. Please check your username and password.", comment: "Login failure")
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .loginFailed:
      return NSLocalizedString(
        "Make sure your credentials are correct and try again.",
        comment: "Login failure recovery suggestion")
    }
  }
}

enum UserError: Error {
  case operationFailed(String)
}

enum ProductError: Error {
  case invalidPrice
  case operationFailed(String)
  case missingImage
  case uploadFailed
  case productNotFound
}

enum CartError: Error {
  case invalidQuantity
  case operationFailed(String)
}

enum OrderError: Error {
  case saveFailed(String)
}

enum TrainMapError: LocalizedError {
  case convexConnectionFailed(String)
  case stationsSubscriptionFailed(String)
  case routesFetchFailed(String)
  case trainPositionsFetchFailed(String)
  case dataMappingFailed(String)
  case networkUnavailable
  case invalidDataFormat(String)

  var errorDescription: String? {
    switch self {
    case .convexConnectionFailed(let details):
      return "Failed to connect to train data service: \(details)"
    case .stationsSubscriptionFailed(let details):
      return "Failed to load train stations: \(details)"
    case .routesFetchFailed(let details):
      return "Failed to load train routes: \(details)"
    case .trainPositionsFetchFailed(let details):
      return "Failed to load train positions: \(details)"
    case .dataMappingFailed(let details):
      return "Failed to process train data: \(details)"
    case .networkUnavailable:
      return "Network connection is unavailable"
    case .invalidDataFormat(let details):
      return "Invalid data format received: \(details)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .convexConnectionFailed, .stationsSubscriptionFailed:
      return
        "Check your internet connection and try again. If the problem persists, the service may be temporarily unavailable."
    case .routesFetchFailed, .trainPositionsFetchFailed:
      return "Try refreshing the map. The train data service may be experiencing issues."
    case .dataMappingFailed, .invalidDataFormat:
      return "The data format has changed. Please update the app to the latest version."
    case .networkUnavailable:
      return "Please check your internet connection and try again."
    }
  }

  var errorName: String {
    switch self {
    case .convexConnectionFailed:
      return "ConvexConnectionError"
    case .stationsSubscriptionFailed:
      return "StationsSubscriptionError"
    case .routesFetchFailed:
      return "RoutesFetchError"
    case .trainPositionsFetchFailed:
      return "TrainPositionsError"
    case .dataMappingFailed:
      return "DataMappingError"
    case .networkUnavailable:
      return "NetworkError"
    case .invalidDataFormat:
      return "DataFormatError"
    }
  }
}
