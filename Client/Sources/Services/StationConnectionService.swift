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
    let args: [String: ConvexEncodable] = ["departureStationId": departureStationId]
    return try await convexClient.query(
      to: "station:list",
      with: args,
      yielding: [Station].self
    )
  }

  /// Fetch all stations (when no departure is selected)
  func fetchAllStations() async throws -> [Station] {
    let args: [String: ConvexEncodable?] = ["departureStationId": nil]
    return try await convexClient.query(
      to: "station:list",
      with: args,
      yielding: [Station].self
    )
  }
}
