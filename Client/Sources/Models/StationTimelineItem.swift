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
  /// Build timeline items from TrainStopService schedule (only actual stops)
  static func buildTimelineFromStops(
    trainCode: String,
    currentSegmentFromStationId: String?,
    trainStopService: TrainStopService
  ) async -> [StationTimelineItem] {
    do {
      guard let schedule = try await trainStopService.getTrainSchedule(trainCode: trainCode) else {
        return []
      }
      
      var items: [StationTimelineItem] = []
      var foundCurrent = false
      
      for (index, stop) in schedule.stops.enumerated() {
        // Determine if this is the current station
        let isCurrent = stop.stationId == currentSegmentFromStationId && !foundCurrent
        if isCurrent { foundCurrent = true }
        
        // Determine state
        let state: StationState
        if foundCurrent && !isCurrent {
          state = .upcoming
        } else if isCurrent {
          state = .current
        } else {
          state = .completed
        }
        
        // Convert time strings to Date (HH:MM:SS format from server)
        let arrivalDate = stop.arrivalTime.flatMap { parseTimeString($0) }
        let departureDate = stop.departureTime.flatMap { parseTimeString($0) }
        
        // Create station model
        let station = Station(
          id: stop.stationId,
          code: stop.stationCode,
          name: stop.stationName,
          position: Position(latitude: 0, longitude: 0), // Not needed for timeline
          city: stop.city
        )
        
        items.append(
          StationTimelineItem(
            id: stop.stationId,
            station: station,
            arrivalTime: arrivalDate,
            departureTime: departureDate,
            state: state,
            isStop: true // All items from trainStops are actual stops
          )
        )
      }
      
      return items
    } catch {
      print("Failed to build timeline from train stops: \(error)")
      return []
    }
  }
  
  /// Parse time string in "HH:MM:SS" format to Date (normalized to today)
  private static func parseTimeString(_ timeString: String) -> Date? {
    let components = timeString.split(separator: ":")
    guard components.count >= 2,
          let hour = Int(components[0]),
          let minute = Int(components[1]) else {
      return nil
    }
    
    let calendar = Calendar.current
    let now = Date()
    let startOfDay = calendar.startOfDay(for: now)
    
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)
  }
}
