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
}
