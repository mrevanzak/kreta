//
//  StationTimelineItem.swift
//  kreta
//
//  Created by AI Assistant
//

import Foundation

// MARK: - Station Timeline Item

/// Represents a station in the journey timeline with its state and timing
struct StationTimelineItem: Identifiable {
  let id: String
  let station: Station
  let arrivalTime: Date?
  let departureTime: Date?
  let state: StationState
  let isStop: Bool // Whether train stops at this station
  
  enum StationState {
    case completed // Train has passed this station
    case current // Train is currently at or approaching this station
    case upcoming // Train hasn't reached this station yet
  }
}

// MARK: - Timeline Builder

extension StationTimelineItem {
  /// Build timeline items from journey data and current train position
  static func buildTimeline(
    from journeyData: TrainJourneyData,
    currentSegmentFromStationId: String?
  ) -> [StationTimelineItem] {
    let stopStationIds = Set(journeyData.stopStationIds())
    let stationsById = Dictionary(
      uniqueKeysWithValues: journeyData.allStations.map { ($0.id ?? $0.code, $0) }
    )
    
    var items: [StationTimelineItem] = []
    var foundCurrent = false
    
    // Add first station (departure)
    if let firstSegment = journeyData.segments.first,
       let firstStation = stationsById[firstSegment.fromStationId] {
      let isCurrent = firstSegment.fromStationId == currentSegmentFromStationId && !foundCurrent
      if isCurrent { foundCurrent = true }
      
      items.append(
        StationTimelineItem(
          id: firstStation.id ?? firstStation.code,
          station: firstStation,
          arrivalTime: nil,
          departureTime: firstSegment.departure,
          state: isCurrent ? .current : .completed,
          isStop: true
        )
      )
    }
    
    // Add intermediate stations based on segments
    for (index, segment) in journeyData.segments.enumerated() {
      guard let station = stationsById[segment.toStationId] else { continue }
      
      let isStop = stopStationIds.contains(segment.toStationId)
      let isCurrent = segment.fromStationId == currentSegmentFromStationId && !foundCurrent
      if isCurrent { foundCurrent = true }
      
      let state: StationState
      if foundCurrent {
        state = .upcoming
      } else if isCurrent {
        state = .current
      } else {
        state = .completed
      }
      
      // Get departure time from next segment if exists
      let departureTime: Date?
      if index < journeyData.segments.count - 1 {
        departureTime = journeyData.segments[index + 1].departure
      } else {
        departureTime = nil // Last station has no departure
      }
      
      items.append(
        StationTimelineItem(
          id: station.id ?? station.code,
          station: station,
          arrivalTime: segment.arrival,
          departureTime: departureTime,
          state: state,
          isStop: isStop,
        )
      )
    }
    
    return items
  }
}
