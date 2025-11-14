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
    let segmentDeparture: Date
    let segmentArrival: Date
    let routeId: String?

    // Optional server-provided fields (extend server DTO if needed)
    let fromStationName: String?
    let toStationName: String?
    let fromStationCode: String?
    let toStationCode: String?
    let durationMinutes: Int?

    private enum CodingKeys: String, CodingKey {
      case id
      case trainId
      case code
      case name
      case fromStationId
      case toStationId
      case segmentDeparture
      case segmentArrival
      case routeId
      case fromStationName
      case toStationName
      case fromStationCode
      case toStationCode
      case durationMinutes
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      trainId = try container.decode(String.self, forKey: .trainId)
      code = try container.decode(String.self, forKey: .code)
      name = try container.decode(String.self, forKey: .name)
      fromStationId = try container.decode(String.self, forKey: .fromStationId)
      toStationId = try container.decode(String.self, forKey: .toStationId)

      // Decode milliseconds directly as Date (server already normalized)
      let departureMs = try container.decode(Int64.self, forKey: .segmentDeparture)
      segmentDeparture = Date(timeIntervalSince1970: TimeInterval(departureMs) / 1000.0)

      let arrivalMs = try container.decode(Int64.self, forKey: .segmentArrival)
      segmentArrival = Date(timeIntervalSince1970: TimeInterval(arrivalMs) / 1000.0)

      routeId = try container.decodeIfPresent(String.self, forKey: .routeId)
      fromStationName = try container.decodeIfPresent(String.self, forKey: .fromStationName)
      toStationName = try container.decodeIfPresent(String.self, forKey: .toStationName)
      fromStationCode = try container.decodeIfPresent(String.self, forKey: .fromStationCode)
      toStationCode = try container.decodeIfPresent(String.self, forKey: .toStationCode)
      durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(trainId, forKey: .trainId)
      try container.encode(code, forKey: .code)
      try container.encode(name, forKey: .name)
      try container.encode(fromStationId, forKey: .fromStationId)
      try container.encode(toStationId, forKey: .toStationId)
      try container.encode(
        Int64(segmentDeparture.timeIntervalSince1970 * 1000), forKey: .segmentDeparture)
      try container.encode(
        Int64(segmentArrival.timeIntervalSince1970 * 1000), forKey: .segmentArrival)
      try container.encodeIfPresent(routeId, forKey: .routeId)
      try container.encodeIfPresent(fromStationName, forKey: .fromStationName)
      try container.encodeIfPresent(toStationName, forKey: .toStationName)
      try container.encodeIfPresent(fromStationCode, forKey: .fromStationCode)
      try container.encodeIfPresent(toStationCode, forKey: .toStationCode)
      try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
    }
  }

  func fetchProjectedForRoute(
    departureStationId: String,
    arrivalStationId: String,
    selectedDate: Date
  ) async throws -> [AvailableTrainItem] {
    let selectedDateMs = Double(selectedDate.timeIntervalSince1970 * 1000)
    return try await convexClient.query(
      to: "journeys:projectedForRoute",
      with: [
        "departureStationId": departureStationId,
        "arrivalStationId": arrivalStationId,
        "selectedDate": selectedDateMs,
      ],
      yielding: [AvailableTrainItem].self
    )
  }

  struct TrainJourneyRow: Codable, Sendable {
    let stationId: String
    let arrival: Date
    let departure: Date
    let trainCode: String
    let trainName: String
    let routeId: String?

    private enum CodingKeys: String, CodingKey {
      case stationId
      case arrivalTime
      case departureTime
      case trainCode
      case trainName
      case routeId
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      stationId = try container.decode(String.self, forKey: .stationId)

      // Decode milliseconds directly as Date (server already normalized)
      let arrivalMs = try container.decode(Double.self, forKey: .arrivalTime)
      arrival = Date(timeIntervalSince1970: arrivalMs / 1000.0)

      let departureMs = try container.decode(Double.self, forKey: .departureTime)
      departure = Date(timeIntervalSince1970: departureMs / 1000.0)

      trainCode = try container.decode(String.self, forKey: .trainCode)
      trainName = try container.decode(String.self, forKey: .trainName)
      routeId = try container.decodeIfPresent(String.self, forKey: .routeId)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(stationId, forKey: .stationId)
      try container.encode(arrival.timeIntervalSince1970 * 1000, forKey: .arrivalTime)
      try container.encode(departure.timeIntervalSince1970 * 1000, forKey: .departureTime)
      try container.encode(trainCode, forKey: .trainCode)
      try container.encode(trainName, forKey: .trainName)
      try container.encodeIfPresent(routeId, forKey: .routeId)
    }
  }

  func fetchSegmentsForTrain(trainId: String, selectedDate: Date) async throws -> [TrainJourneyRow]
  {
    let selectedDateMs = Double(selectedDate.timeIntervalSince1970 * 1000)
    return try await convexClient.query(
      to: "journeys:segmentsForTrain",
      with: [
        "trainId": trainId,
        "selectedDate": selectedDateMs,
      ],
      yielding: [TrainJourneyRow].self
    )
  }
}
