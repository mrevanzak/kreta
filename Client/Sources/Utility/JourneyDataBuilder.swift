import Foundation
import OSLog

/// Helper utility for building journey data structures with consistent date normalization
enum JourneyDataBuilder {
  private static let logger = Logger(subsystem: "kreta", category: "JourneyDataBuilder")

  /// Build journey segments from server response rows
  /// Converts TrainJourneyRow array to JourneySegment array
  /// Server already normalized times to selected date
  /// - Parameters:
  ///   - rows: Server response rows ordered by departure time (already normalized)
  /// - Returns: Array of JourneySegment objects
  static func buildJourneySegments(
    from rows: [JourneyService.TrainJourneyRow]
  ) -> [JourneySegment] {
    guard rows.count >= 2 else {
      logger.warning("Insufficient rows to build journey segments: \(rows.count)")
      return []
    }

    var segments: [JourneySegment] = []

    for index in 0..<(rows.count - 1) {
      let currentRow = rows[index]
      let nextRow = rows[index + 1]

      // Server already normalized times, use directly
      // Use nextRow.routeId because the route connects TO the next station
      let segment = JourneySegment(
        fromStationId: currentRow.stationId,
        toStationId: nextRow.stationId,
        departure: currentRow.departure,
        arrival: nextRow.arrival,
        routeId: nextRow.routeId
      )

      segments.append(segment)
    }

    logger.debug("Built \(segments.count) journey segments from \(rows.count) rows")
    return segments
  }

  /// Build TrainJourneyData from segments and station information
  /// Server already normalized times to selected date
  /// - Parameters:
  ///   - trainId: The train identifier
  ///   - segments: Journey segments (already normalized)
  ///   - allStations: All stations in the journey
  ///   - fromStation: User-selected departure station
  ///   - toStation: User-selected arrival station
  ///   - userSelectedDepartureTime: User-selected departure time (already normalized)
  ///   - userSelectedArrivalTime: User-selected arrival time (already normalized)
  ///   - selectedDate: The date the journey is scheduled for
  /// - Returns: TrainJourneyData object
  static func buildTrainJourneyData(
    trainId: String,
    segments: [JourneySegment],
    allStations: [Station],
    fromStation: Station,
    toStation: Station,
    userSelectedDepartureTime: Date,
    userSelectedArrivalTime: Date,
    selectedDate: Date
  ) -> TrainJourneyData {
    logger.debug(
      "Building TrainJourneyData for trainId='\(trainId, privacy: .public)', segments=\(segments.count), stations=\(allStations.count)"
    )

    return TrainJourneyData(
      trainId: trainId,
      segments: segments,
      allStations: allStations,
      userSelectedFromStation: fromStation,
      userSelectedToStation: toStation,
      userSelectedDepartureTime: userSelectedDepartureTime,
      userSelectedArrivalTime: userSelectedArrivalTime,
      selectedDate: selectedDate
    )
  }

  /// Build journey segments and collect all stations from server rows
  /// Server already normalized times to selected date
  /// - Parameters:
  ///   - rows: Server response rows (already normalized)
  ///   - stationsById: Dictionary for station lookup
  /// - Returns: Tuple of (segments, allStations)
  static func buildSegmentsAndStations(
    from rows: [JourneyService.TrainJourneyRow],
    stationsById: [String: Station]
  ) -> (segments: [JourneySegment], allStations: [Station]) {
    let segments = buildJourneySegments(from: rows)

    var allStations: [Station] = []
    var seenStationIds = Set<String>()

    // Collect unique stations from segments
    for segment in segments {
      if !seenStationIds.contains(segment.fromStationId),
        let station = stationsById[segment.fromStationId]
      {
        allStations.append(station)
        seenStationIds.insert(segment.fromStationId)
      }

      if !seenStationIds.contains(segment.toStationId),
        let station = stationsById[segment.toStationId]
      {
        allStations.append(station)
        seenStationIds.insert(segment.toStationId)
      }
    }

    logger.debug(
      "Built \(segments.count) segments and collected \(allStations.count) unique stations"
    )

    return (segments, allStations)
  }

  /// Build TrainJourney object for projection
  /// - Parameters:
  ///   - trainId: The train identifier
  ///   - trainCode: The train code
  ///   - trainName: The train name
  ///   - segments: Journey segments
  /// - Returns: TrainJourney object
  static func buildTrainJourney(
    trainId: String,
    trainCode: String,
    trainName: String,
    segments: [JourneySegment]
  ) -> TrainJourney {
    TrainJourney(
      id: trainId,
      trainId: trainId,
      code: trainCode,
      name: trainName,
      segments: segments
    )
  }

  /// Validate journey data before building
  /// - Parameters:
  ///   - rows: Server response rows
  ///   - fromStation: Expected departure station
  ///   - toStation: Expected arrival station
  /// - Returns: Optional error message if validation fails
  static func validateJourneyData(
    rows: [JourneyService.TrainJourneyRow],
    fromStation: Station,
    toStation: Station
  ) -> String? {
    guard !rows.isEmpty else {
      return "No journey rows provided"
    }

    guard let firstRow = rows.first else {
      return "Empty journey rows array"
    }

    guard let lastRow = rows.last else {
      return "Could not get last journey row"
    }

    // Validate that first station matches departure
    if firstRow.stationId != fromStation.id && firstRow.stationId != fromStation.code {
      logger.warning(
        "First station ID '\(firstRow.stationId, privacy: .public)' does not match departure station '\(fromStation.code, privacy: .public)'"
      )
    }

    // Validate that last station matches arrival
    if lastRow.stationId != toStation.id && lastRow.stationId != toStation.code {
      logger.warning(
        "Last station ID '\(lastRow.stationId, privacy: .public)' does not match arrival station '\(toStation.code, privacy: .public)'"
      )
    }

    return nil
  }
}
