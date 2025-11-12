import Foundation

extension Date {
  /// Extract hour and minute from milliseconds since epoch
  static func extractHourMinute(from milliseconds: Int64) -> (hour: Int, minute: Int) {
    let seconds = TimeInterval(milliseconds) / 1000.0
    let date = Date(timeIntervalSince1970: seconds)
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute], from: date)
    return (hour: components.hour ?? 0, minute: components.minute ?? 0)
  }

  /// Extract hour and minute from milliseconds since epoch (Double)
  static func extractHourMinute(from milliseconds: Double) -> (hour: Int, minute: Int) {
    let seconds = milliseconds / 1000.0
    let date = Date(timeIntervalSince1970: seconds)
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute], from: date)
    return (hour: components.hour ?? 0, minute: components.minute ?? 0)
  }

  /// Create a Date from milliseconds since epoch, extracting only hour:minute and applying to today's local date
  init(fromMillisecondsSinceEpoch ms: Int64, applyingToLocalDate date: Date = Date()) {
    let (hour, minute) = Date.extractHourMinute(from: ms)
    let calendar = Calendar.current
    let baseDate = calendar.startOfDay(for: date)
    self =
      calendar.date(
        bySettingHour: hour,
        minute: minute,
        second: 0,
        of: baseDate
      ) ?? date
  }

  /// Create a Date from milliseconds since epoch (Double), extracting only hour:minute and applying to today's local date
  init(fromMillisecondsSinceEpoch ms: Double, applyingToLocalDate date: Date = Date()) {
    let (hour, minute) = Date.extractHourMinute(from: ms)
    let calendar = Calendar.current
    let baseDate = calendar.startOfDay(for: date)
    self =
      calendar.date(
        bySettingHour: hour,
        minute: minute,
        second: 0,
        of: baseDate
      ) ?? date
  }

  /// Normalizes arrival time to be after departure time
  /// If arrival hour is less than departure hour (e.g., 01:00 vs 20:00),
  /// adds 24 hours to arrival time to represent next-day arrival
  /// - Parameters:
  ///   - arrival: The arrival time to normalize
  ///   - departure: The departure time to compare against
  /// - Returns: Normalized arrival time that is guaranteed to be after departure time
  static func normalizeArrivalTime(arrival: Date, relativeTo departure: Date) -> Date {
    let calendar = Calendar.current
    
    // Extract hour and minute components from both dates
    let arrivalComponents = calendar.dateComponents([.hour, .minute], from: arrival)
    let departureComponents = calendar.dateComponents([.hour, .minute], from: departure)
    
    guard let arrivalHour = arrivalComponents.hour,
          let arrivalMinute = arrivalComponents.minute,
          let departureHour = departureComponents.hour,
          let departureMinute = departureComponents.minute
    else {
      // If we can't extract components, return arrival as-is
      return arrival
    }
    
    // Calculate time in minutes since midnight for comparison
    let arrivalMinutes = arrivalHour * 60 + arrivalMinute
    let departureMinutes = departureHour * 60 + departureMinute
    
    // If arrival time is earlier in the day than departure, it's next day
    if arrivalMinutes < departureMinutes {
      // Add 24 hours to arrival time
      return calendar.date(byAdding: .hour, value: 24, to: arrival) ?? arrival
    }
    
    // Arrival is already after departure, return as-is
    return arrival
  }
}
