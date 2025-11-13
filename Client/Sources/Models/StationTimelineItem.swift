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
    selectedDate: Date = Date(), // Date to normalize times to
    userDestinationStationId: String? = nil // User's selected destination station
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
      
      // Check if train has departed from the first station
      let now = Date()
      var firstStopDeparture = schedule.stops.first?.departureTime.flatMap { parseTimeString($0, on: selectedDate) }
      
      // Handle midnight-spanning journeys: if last arrival time-of-day is earlier than first departure time-of-day,
      // the journey spans midnight. If we're currently between midnight and arrival, departure was yesterday.
      if let departure = firstStopDeparture,
         let lastStop = schedule.stops.last,
         let lastArrival = lastStop.arrivalTime.flatMap({ parseTimeString($0, on: selectedDate) }),
         lastArrival < departure { // Arrival time-of-day < Departure time-of-day = midnight span
        
        // Check if we're between midnight and the arrival time
        // If now < arrival (time-of-day), we're in the "next day" portion of the journey
        if now < lastArrival {
          // Adjust departure to yesterday
          firstStopDeparture = calendar.date(byAdding: .day, value: -1, to: departure)
        }
      }
      
      let hasTrainDeparted = firstStopDeparture.map { now >= $0 } ?? false
      
      // Check if train has arrived at user's destination (if specified)
      var hasArrivedAtDestination = false
      if let destinationId = userDestinationStationId,
         let destinationStop = schedule.stops.first(where: { $0.stationId == destinationId }) {
        var arrivalTime = destinationStop.arrivalTime.flatMap({ parseTimeString($0, on: selectedDate) })
        
        // Handle midnight-spanning: if destination arrival is earlier than first departure (time-of-day),
        // and we adjusted departure to yesterday, also check if we need to keep arrival as today
        if let arrival = arrivalTime, let departure = firstStopDeparture, arrival < departure {
          // This means arrival is in the "next day" portion - keep it as-is (today)
          // No adjustment needed since it's already normalized to selectedDate
        }
        
        hasArrivedAtDestination = arrivalTime.map { now >= $0 } ?? false
      }
      
      var items: [StationTimelineItem] = []
      var foundCurrent = false
      
      for (index, stop) in schedule.stops.enumerated() {
        // Convert time strings to Date (HH:MM:SS format from server)
        let arrivalDate = stop.arrivalTime.flatMap { parseTimeString($0, on: selectedDate) }
        let departureDate = stop.departureTime.flatMap { parseTimeString($0, on: selectedDate) }
        
        // Determine if this is the current station (only if journey is today AND train has departed)
        let isCurrent = !isJourneyInFuture && hasTrainDeparted && stop.stationId == currentSegmentFromStationId && !foundCurrent
        if isCurrent { foundCurrent = true }
        
        // Determine state based on journey date and departure status
        let state: StationState
        if isJourneyInFuture {
          // If journey is in the future, all stations are upcoming
          state = .upcoming
        } else if !hasTrainDeparted {
          // If journey is today but train hasn't departed yet, all stations are upcoming
          state = .upcoming
        } else if hasArrivedAtDestination && currentSegmentFromStationId == nil {
          // Train has arrived at user's destination AND no active segment - mark all as completed
          state = .completed
        } else {
          // Train has departed but not arrived yet (or still has active position) - use normal logic
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
