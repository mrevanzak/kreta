//
//  JourneyService.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 30/10/25.
//

import ConvexMobile
import Foundation

@MainActor
final class JourneyService {
  private let convexClient = Dependencies.shared.convexClient

  struct AvailableTrainItem: Codable, Identifiable, Sendable {
    let id: String
    let trainId: String
    let code: String
    let name: String
    let fromStationId: String
    let toStationId: String
    let segmentDepartureMs: Int64
    let segmentArrivalMs: Int64
    let routeId: String?

    // Optional server-provided fields (extend server DTO if needed)
    let fromStationName: String?
    let toStationName: String?
    let fromStationCode: String?
    let toStationCode: String?
    let durationMinutes: Int?
  }

  func fetchProjectedForRoute(
    departureStationId: String,
    arrivalStationId: String
  ) async throws -> [AvailableTrainItem] {
    return try await convexClient.query(
      to: "journeys:projectedForRoute",
      with: [
        "departureStationId": departureStationId,
        "arrivalStationId": arrivalStationId,
      ],
      yielding: [AvailableTrainItem].self
    )
  }

  struct TrainJourneyRow: Codable, Sendable {
    let stationId: String
    let arrivalTime: Int64
    let departureTime: Int64
    let trainCode: String
    let trainName: String
    let routeId: String?
  }

  func fetchSegmentsForTrain(trainId: String) async throws -> [TrainJourneyRow] {
    return try await convexClient.query(
      to: "journeys:segmentsForTrain",
      with: ["trainId": trainId],
      yielding: [TrainJourneyRow].self
    )
  }
}
