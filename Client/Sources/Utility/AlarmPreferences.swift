import Foundation

/// Utility for managing alarm preferences with per-activity and global defaults
final class AlarmPreferences: @unchecked Sendable {
  static let shared = AlarmPreferences()

  private let userDefaults = UserDefaults.standard

  // MARK: - Keys
  private enum Keys {
    static let defaultAlarmEnabled = "alarm.defaultEnabled"
    static let defaultAlarmOffsetMinutes = "alarm.defaultOffsetMinutes"
    static func alarmEnabled(activityId: String) -> String { "alarm.enabled.\(activityId)" }
    static func alarmOffsetMinutes(activityId: String) -> String {
      "alarm.offsetMinutes.\(activityId)"
    }
  }

  private init() {}

  // MARK: - Global Defaults

  /// Global default for whether alarms are enabled
  var defaultAlarmEnabled: Bool {
    get {
      // If not set, defaults to true
      if userDefaults.object(forKey: Keys.defaultAlarmEnabled) == nil {
        return true
      }
      return userDefaults.bool(forKey: Keys.defaultAlarmEnabled)
    }
    set {
      userDefaults.set(newValue, forKey: Keys.defaultAlarmEnabled)
    }
  }

  /// Global default for alarm offset in minutes
  var defaultAlarmOffsetMinutes: Int {
    get {
      // If not set, defaults to 10 minutes
      let value = userDefaults.integer(forKey: Keys.defaultAlarmOffsetMinutes)
      return value > 0 ? value : 10
    }
    set {
      userDefaults.set(newValue, forKey: Keys.defaultAlarmOffsetMinutes)
    }
  }

  // MARK: - Per-Activity Preferences

  /// Get alarm enabled setting for a specific activity
  /// Falls back to global default if not set
  func alarmEnabled(for activityId: String) -> Bool {
    // If explicitly set for this activity, use that value
    if userDefaults.object(forKey: Keys.alarmEnabled(activityId: activityId)) is Bool {
      return userDefaults.bool(forKey: Keys.alarmEnabled(activityId: activityId))
    }
    // Otherwise use global default
    return defaultAlarmEnabled
  }

  /// Set alarm enabled setting for a specific activity
  func setAlarmEnabled(_ enabled: Bool, for activityId: String) {
    userDefaults.set(enabled, forKey: Keys.alarmEnabled(activityId: activityId))
  }

  /// Get alarm offset for a specific activity
  /// Falls back to global default if not set
  func alarmOffsetMinutes(for activityId: String) -> Int {
    // If explicitly set for this activity, use that value
    let value = userDefaults.integer(forKey: Keys.alarmOffsetMinutes(activityId: activityId))
    if value > 0 {
      return value
    }
    // Otherwise use global default
    return defaultAlarmOffsetMinutes
  }

  /// Set alarm offset for a specific activity
  func setAlarmOffsetMinutes(_ minutes: Int, for activityId: String) {
    userDefaults.set(minutes, forKey: Keys.alarmOffsetMinutes(activityId: activityId))
  }

  /// Remove all preferences for a specific activity
  func clearPreferences(for activityId: String) {
    userDefaults.removeObject(forKey: Keys.alarmEnabled(activityId: activityId))
    userDefaults.removeObject(forKey: Keys.alarmOffsetMinutes(activityId: activityId))
  }

  /// Clear all global defaults (resets to hardcoded defaults)
  func clearGlobalDefaults() {
    userDefaults.removeObject(forKey: Keys.defaultAlarmEnabled)
    userDefaults.removeObject(forKey: Keys.defaultAlarmOffsetMinutes)
  }
}
