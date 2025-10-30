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
    let args: [String: ConvexEncodable] = [
      "departureStationId": departureStationId,
      "arrivalStationId": arrivalStationId,
    ]
    return try await convexClient.query(
      to: "train:list",
      with: args,
      yielding: [Train].self
    )
  }
}
