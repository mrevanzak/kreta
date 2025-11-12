//
//  StationTimelineItem.swift
//  kreta
//
//  Created by AI Assistant
//

import Foundation

// MARK: - Station Timeline Item

/// Represents a station in the journey timeline with its state and timing
struct StationTimelineItem: Identifiable, Equatable {
  let id: String
  let station: Station
  let arrivalTime: Date?
  let departureTime: Date?
  let state: StationState
  let isStop: Bool // Whether train stops at this station
  var progressToNext: Double? // Progress from this station to next (0.0 - 1.0)
  
  enum StationState: Equatable {
    case completed // Train has passed this station
    case current // Train is currently at or approaching this station
    case upcoming // Train hasn't reached this station yet
  }
  
  /// Calculate progress between two stations based on current time
  /// Note: If departure/arrival are on a future date, progress will be 0.0
  static func calculateProgress(from departure: Date?, to arrival: Date?) -> Double? {
    guard let departure = departure, let arrival = arrival else {
      return nil
    }
    
    let now = Date()
    let calendar = Calendar.current
    
    // Check if the journey is on a future date (not today)
    // Compare just the date components, not the time
    let departureDay = calendar.startOfDay(for: departure)
    let today = calendar.startOfDay(for: now)
    
    // If journey is on a future date, no progress yet
    if departureDay > today {
      return 0.0
    }
    
    // If before departure, progress is 0
    if now < departure {
      return 0.0
    }
    
    // If after arrival, progress is 1
    if now >= arrival {
      return 1.0
    }
    
    // Calculate progress between 0 and 1
    let totalDuration = arrival.timeIntervalSince(departure)
    let elapsed = now.timeIntervalSince(departure)
    
    return min(max(elapsed / totalDuration, 0.0), 1.0)
  }
}

// MARK: - Timeline Builder

extension StationTimelineItem {
  /// Build timeline items from TrainStopService schedule (only actual stops)
  static func buildTimelineFromStops(
    trainCode: String,
    currentSegmentFromStationId: String?,
    trainStopService: TrainStopService,
    selectedDate: Date = Date() // Date to normalize times to
  ) async -> [StationTimelineItem] {
    do {
      guard let schedule = try await trainStopService.getTrainSchedule(trainCode: trainCode) else {
        return []
      }
      
      // Check if journey is on a future date
      let calendar = Calendar.current
      let journeyDay = calendar.startOfDay(for: selectedDate)
      let today = calendar.startOfDay(for: Date())
      let isJourneyInFuture = journeyDay > today
      
      var items: [StationTimelineItem] = []
      var foundCurrent = false
      
      for (index, stop) in schedule.stops.enumerated() {
        // Convert time strings to Date (HH:MM:SS format from server)
        let arrivalDate = stop.arrivalTime.flatMap { parseTimeString($0, on: selectedDate) }
        let departureDate = stop.departureTime.flatMap { parseTimeString($0, on: selectedDate) }
        
        // Determine if this is the current station (only if journey is today)
        let isCurrent = !isJourneyInFuture && stop.stationId == currentSegmentFromStationId && !foundCurrent
        if isCurrent { foundCurrent = true }
        
        // Determine state based on journey date
        let state: StationState
        if isJourneyInFuture {
          // If journey is in the future, all stations are upcoming
          state = .upcoming
        } else {
          // For today's journey, use normal logic
          if foundCurrent && !isCurrent {
            state = .upcoming
          } else if isCurrent {
            state = .current
          } else {
            state = .completed
          }
        }
        
        // Calculate progress to next station
        var progressToNext: Double? = nil
        if index < schedule.stops.count - 1 {
          let nextStop = schedule.stops[index + 1]
          let nextArrival = nextStop.arrivalTime.flatMap { parseTimeString($0, on: selectedDate) }
          
          // Use departure time of current station and arrival time of next station
          let currentDeparture = departureDate ?? arrivalDate
          progressToNext = calculateProgress(from: currentDeparture, to: nextArrival)
        }
        
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
            isStop: true, // All items from trainStops are actual stops
            progressToNext: progressToNext
          )
        )
      }
      
      return items
    } catch {
      print("Failed to build timeline from train stops: \(error)")
      return []
    }
  }
  
  /// Parse time string in "HH:MM:SS" format to Date (normalized to selected date)
  private static func parseTimeString(_ timeString: String, on date: Date) -> Date? {
    let components = timeString.split(separator: ":")
    guard components.count >= 2,
          let hour = Int(components[0]),
          let minute = Int(components[1]) else {
      return nil
    }
    
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)
  }
}
