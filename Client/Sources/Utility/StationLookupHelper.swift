import Foundation
import OSLog

/// Helper utility for station lookup operations with multi-strategy support
enum StationLookupHelper {
  private static let logger = Logger(subsystem: "kreta", category: "StationLookupHelper")

  /// Build a dictionary mapping station IDs to Station objects
  /// Uses station.id if available, falls back to station.code
  static func buildStationsById(_ stations: [Station]) -> [String: Station] {
    var mapping: [String: Station] = [:]

    for station in stations {
      if let id = station.id {
        mapping[id] = station
      }
      // Also map by code as fallback
      mapping[station.code] = station
    }

    logger.debug(
      "Built stationsById mapping with \(mapping.count) entries from \(stations.count) stations")
    return mapping
  }

  /// Build a dictionary mapping station codes to Station objects
  static func buildStationsByCode(_ stations: [Station]) -> [String: Station] {
    Dictionary(uniqueKeysWithValues: stations.map { ($0.code, $0) })
  }

  /// Build a comprehensive station lookup dictionary using multi-strategy approach
  /// Includes: station.id, station.code, and journey-specific stations
  static func buildComprehensiveLookup(
    stations: [Station],
    journeyStations: [Station] = []
  ) -> [String: Station] {
    var mapping: [String: Station] = [:]

    // Strategy 1: Map by station.id (primary key)
    for station in stations where station.id != nil {
      mapping[station.id!] = station
    }

    // Strategy 2: Map by station.code (fallback for code-based lookups)
    for station in stations {
      mapping[station.code] = station
    }

    // Strategy 3: Include journey-specific stations
    for station in journeyStations {
      if let id = station.id {
        mapping[id] = station
      }
      mapping[station.code] = station
    }

    logger.debug(
      "Built comprehensive lookup with \(mapping.count) entries from \(stations.count) stations, \(journeyStations.count) journey stations"
    )
    return mapping
  }

  /// Find a station by ID or code with fallback strategies
  /// - Parameters:
  ///   - identifier: Station ID or code to search for
  ///   - stations: Array of stations to search in
  ///   - journeyStations: Optional journey-specific stations to include
  /// - Returns: Found station or nil
  static func findStation(
    by identifier: String,
    in stations: [Station],
    journeyStations: [Station] = []
  ) -> Station? {
    let lookup = buildComprehensiveLookup(stations: stations, journeyStations: journeyStations)

    if let station = lookup[identifier] {
      logger.debug(
        "Found station '\(station.name, privacy: .public)' (\(station.code, privacy: .public)) by identifier '\(identifier, privacy: .public)'"
      )
      return station
    }

    logger.warning("Station not found for identifier '\(identifier, privacy: .public)'")
    return nil
  }

  /// Find stations by codes (for deep link handling)
  /// - Parameters:
  ///   - fromCode: Departure station code
  ///   - toCode: Arrival station code
  ///   - stations: Array of stations to search in
  /// - Returns: Tuple of (fromStation, toStation) or nil if either not found
  static func findStationsByCodes(
    fromCode: String,
    toCode: String,
    in stations: [Station]
  ) -> (from: Station, to: Station)? {
    let stationsByCode = buildStationsByCode(stations)

    guard let fromStation = stationsByCode[fromCode] else {
      logger.error("Could not find departure station with code '\(fromCode, privacy: .public)'")
      return nil
    }

    guard let toStation = stationsByCode[toCode] else {
      logger.error("Could not find arrival station with code '\(toCode, privacy: .public)'")
      return nil
    }

    logger.debug(
      "Found stations: from='\(fromStation.name, privacy: .public)' (\(fromCode, privacy: .public)), to='\(toStation.name, privacy: .public)' (\(toCode, privacy: .public))"
    )
    return (fromStation, toStation)
  }

  /// Build segment-to-station mapping for journey segments
  /// Handles cases where server station IDs don't match cached station IDs
  static func buildSegmentStationMapping(
    segments: [JourneySegment],
    stations: [Station],
    knownMappings: [String: Station] = [:]
  ) -> [String: Station] {
    var segmentIdToStation: [String: Station] = knownMappings
    let stationsById = buildStationsById(stations)

    // Map known stations first (from deep link parameters)
    for (segmentId, station) in knownMappings {
      segmentIdToStation[segmentId] = station
    }

    // For other segments, try to find stations by ID or code
    for segment in segments {
      if segmentIdToStation[segment.fromStationId] == nil {
        // Try ID lookup first
        if let station = stationsById[segment.fromStationId] {
          segmentIdToStation[segment.fromStationId] = station
        }
      }

      if segmentIdToStation[segment.toStationId] == nil {
        if let station = stationsById[segment.toStationId] {
          segmentIdToStation[segment.toStationId] = station
        }
      }
    }

    let mappedCount = segmentIdToStation.count
    let totalSegments = segments.count * 2  // from + to for each segment
    logger.debug(
      "Built segment station mapping: \(mappedCount)/\(totalSegments) stations mapped"
    )

    return segmentIdToStation
  }
}
