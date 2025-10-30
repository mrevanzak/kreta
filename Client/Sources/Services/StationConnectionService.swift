//
//  StationConnectionService.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 30/10/25.
//

import Combine
import ConvexMobile
import Foundation

@MainActor
final class StationConnectionService {
  private let convexClient = Dependencies.shared.convexClient
  
  /// Fetch connected stations for a given departure station
  func fetchConnectedStations(departureStationId: String) async throws -> [Station] {
    try await withCheckedThrowingContinuation { continuation in
      var didResume = false
      var cancellable: AnyCancellable?
      
      let args: [String: ConvexEncodable] = ["departureStationId": departureStationId]
      
      cancellable = convexClient.subscribe(
        to: "station:list",
        with: args,
        yielding: [Station].self
      )
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { completion in
          if case let .failure(error) = completion, !didResume {
            didResume = true
            continuation.resume(throwing: error)
          }
        },
        receiveValue: { stations in
          guard !didResume else { return }
          cancellable?.cancel()
          didResume = true
          continuation.resume(returning: stations)
        }
      )
    }
  }
  
  /// Fetch all stations (when no departure is selected)
  func fetchAllStations() async throws -> [Station] {
    try await withCheckedThrowingContinuation { continuation in
      var didResume = false
      var cancellable: AnyCancellable?
      
      let args: [String: ConvexEncodable?] = ["departureStationId": nil]
      
      cancellable = convexClient.subscribe(
        to: "station:list",
        with: args,
        yielding: [Station].self
      )
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { completion in
          if case let .failure(error) = completion, !didResume {
            didResume = true
            continuation.resume(throwing: error)
          }
        },
        receiveValue: { stations in
          guard !didResume else { return }
          cancellable?.cancel()
          didResume = true
          continuation.resume(returning: stations)
        }
      )
    }
  }
}
