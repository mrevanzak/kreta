//
//  TrainConnectionService.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 30/10/25.
//

import Combine
import ConvexMobile
import Foundation

@MainActor
final class TrainConnectionService {
  private let convexClient = Dependencies.shared.convexClient
  
  /// Fetch trains that connect two stations
  func fetchTrains(
    departureStationId: String,
    arrivalStationId: String
  ) async throws -> [Train] {
    try await withCheckedThrowingContinuation { continuation in
      var didResume = false
      var cancellable: AnyCancellable?
      
      let args: [String: ConvexEncodable] = [
        "departureStationId": departureStationId,
        "arrivalStationId": arrivalStationId
      ]
      
      cancellable = convexClient.subscribe(
        to: "train:list",
        with: args,
        yielding: [Train].self
      )
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { completion in
          if case let .failure(error) = completion, !didResume {
            didResume = true
            continuation.resume(throwing: error)
          }
        },
        receiveValue: { trains in
          guard !didResume else { return }
          cancellable?.cancel()
          didResume = true
          continuation.resume(returning: trains)
        }
      )
    }
  }
}
