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
  case stationsFetchFailed(String)
  case routesFetchFailed(String)
  case trainPositionsFetchFailed(String)
  case dataMappingFailed(String)
  case networkUnavailable
  case invalidDataFormat(String)
  case missingDeviceToken

  var errorDescription: String? {
    switch self {
    case .convexConnectionFailed(let details):
      return "Failed to connect to train data service: \(details)"
    case .stationsFetchFailed(let details):
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
    case .missingDeviceToken:
      return "Internal error: Device token not available"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .convexConnectionFailed, .stationsFetchFailed:
      return
        "Check your internet connection and try again. If the problem persists, the service may be temporarily unavailable."
    case .routesFetchFailed, .trainPositionsFetchFailed:
      return "Try refreshing the map. The train data service may be experiencing issues."
    case .dataMappingFailed, .invalidDataFormat:
      return "The data format has changed. Please update the app to the latest version."
    case .networkUnavailable:
      return "Please check your internet connection and try again."
    case .missingDeviceToken:
      return nil
    }
  }

  var errorName: String {
    switch self {
    case .convexConnectionFailed:
      return "ConvexConnectionError"
    case .stationsFetchFailed:
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
    case .missingDeviceToken:
      return "DeviceTokenError"
    }
  }
}
