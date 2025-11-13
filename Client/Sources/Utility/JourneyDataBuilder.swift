import Foundation
import OSLog

/// Helper utility for building journey data structures with consistent date normalization
enum JourneyDataBuilder {
  private static let logger = Logger(subsystem: "kreta", category: "JourneyDataBuilder")

  /// Build journey segments from server response rows
  /// Converts TrainJourneyRow array to JourneySegment array with date normalization
  /// - Parameters:
  ///   - rows: Server response rows ordered by departure time
  ///   - selectedDate: The date to normalize times to
  /// - Returns: Array of JourneySegment objects
  static func buildJourneySegments(
    from rows: [JourneyService.TrainJourneyRow],
    selectedDate: Date
  ) -> [JourneySegment] {
    guard rows.count >= 2 else {
      logger.warning("Insufficient rows to build journey segments: \(rows.count)")
      return []
    }

    var segments: [JourneySegment] = []

    for index in 0..<(rows.count - 1) {
      let currentRow = rows[index]
      let nextRow = rows[index + 1]

      // Normalize segment times to selected date
      let normalizedDeparture = Date.normalizeTimeToDate(currentRow.departure, to: selectedDate)
      let normalizedArrival = Date.normalizeArrivalTime(
        departure: normalizedDeparture,
        arrival: Date.normalizeTimeToDate(nextRow.arrival, to: selectedDate)
      )

      // Use nextRow.routeId because the route connects TO the next station
      let segment = JourneySegment(
        fromStationId: currentRow.stationId,
        toStationId: nextRow.stationId,
        departure: normalizedDeparture,
        arrival: normalizedArrival,
        routeId: nextRow.routeId
      )

      segments.append(segment)
    }

    logger.debug("Built \(segments.count) journey segments from \(rows.count) rows")
    return segments
  }

  /// Build TrainJourneyData from segments and station information
  /// - Parameters:
  ///   - trainId: The train identifier
  ///   - segments: Journey segments
  ///   - allStations: All stations in the journey
  ///   - fromStation: User-selected departure station
  ///   - toStation: User-selected arrival station
  ///   - userSelectedDepartureTime: User-selected departure time
  ///   - userSelectedArrivalTime: User-selected arrival time
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
    let normalizedArrival = Date.normalizeArrivalTime(
      departure: userSelectedDepartureTime,
      arrival: userSelectedArrivalTime
    )

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
      userSelectedArrivalTime: normalizedArrival,
      selectedDate: selectedDate
    )
  }

  /// Build journey segments and collect all stations from server rows
  /// - Parameters:
  ///   - rows: Server response rows
  ///   - selectedDate: The date to normalize times to
  ///   - stationsById: Dictionary for station lookup
  /// - Returns: Tuple of (segments, allStations)
  static func buildSegmentsAndStations(
    from rows: [JourneyService.TrainJourneyRow],
    selectedDate: Date,
    stationsById: [String: Station]
  ) -> (segments: [JourneySegment], allStations: [Station]) {
    let segments = buildJourneySegments(from: rows, selectedDate: selectedDate)

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
