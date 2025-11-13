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

  /// Normalize arrival time for next-day journeys
  /// If arrival is before departure, assumes it's the next day and adds 24 hours
  /// - Parameters:
  ///   - departure: The departure time
  ///   - arrival: The arrival time to normalize
  /// - Returns: The normalized arrival time (arrival + 24 hours if arrival < departure)
  static func normalizeArrivalTime(departure: Date, arrival: Date) -> Date {
    if arrival < departure {
      return arrival.addingTimeInterval(24 * 60 * 60)  // Add 24 hours
    }
    return arrival
  }

  /// Normalize a time to a specific date (extract hour:minute and apply to target date)
  /// This is useful for normalizing server times to user-selected dates
  /// - Parameters:
  ///   - time: The source time to extract hour:minute from
  ///   - targetDate: The target date to apply the time to
  /// - Returns: A new Date with the hour:minute from time applied to targetDate
  static func normalizeTimeToDate(_ time: Date, to targetDate: Date) -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute], from: time)
    let startOfDay = calendar.startOfDay(for: targetDate)

    guard let hour = components.hour, let minute = components.minute else {
      return time
    }

    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) ?? time
  }
}
