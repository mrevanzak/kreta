import Foundation

// MARK: - AnalyticsEventService

final class AnalyticsEventService: @unchecked Sendable {
  static let shared = AnalyticsEventService()

  private let telemetry: Telemetry
  private let userDefaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  // Keep last N journeys for round-trip detection
  private let maxStoredJourneys = 10
  private let roundTripWindowDays: Int = 7

  private enum StorageKeys {
    static let journeyHistory = "analytics.journeyHistory"
  }

  private init(
    telemetry: Telemetry = Dependencies.shared.telemetry,
    userDefaults: UserDefaults = .standard
  ) {
    self.telemetry = telemetry
    self.userDefaults = userDefaults
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  // MARK: - Models

  struct JourneyRecord: Codable, Equatable {
    let trainId: String
    let fromStationId: String
    let toStationId: String
    let completedAt: Date

    var directionKey: String { "\(fromStationId)->\(toStationId)" }
  }

  // MARK: - Core Journey Events

  func trackJourneyStarted(
    trainId: String,
    trainName: String,
    from: Station,
    to: Station,
    userSelectedDeparture: Date,
    userSelectedArrival: Date,
    hasAlarmEnabled: Bool
  ) {
    let now = Date()
    let durationMinutes = Int(userSelectedArrival.timeIntervalSince(userSelectedDeparture) / 60)
    let timeUntilDepartureMinutes = Int(max(0, userSelectedDeparture.timeIntervalSince(now)) / 60)

    telemetry.track(
      event: "journey_started",
      properties: [
        "train_id": trainId,
        "train_name": trainName,
        "from_station_id": from.id ?? from.code,
        "from_station_name": from.name,
        "to_station_id": to.id ?? to.code,
        "to_station_name": to.name,
        "departure_time": iso8601String(userSelectedDeparture),
        "arrival_time": iso8601String(userSelectedArrival),
        "journey_duration_minutes": durationMinutes,
        "time_until_departure_minutes": timeUntilDepartureMinutes,
        "has_alarm_enabled": hasAlarmEnabled,
      ]
    )
  }

  func trackJourneyCancelled(trainId: String, reason: String?, context: [String: Any] = [:]) {
    var props: [String: Any] = [
      "train_id": trainId
    ]
    if let reason { props["reason"] = reason }
    for (k, v) in context { props[k] = v }
    telemetry.track(event: "journey_cancelled", properties: props)
  }

  /// Track completion with full context (preferred).
  func trackJourneyCompleted(
    trainId: String,
    from: Station,
    to: Station,
    userSelectedDeparture: Date,
    completionType: String,  // "arrival_screen" | "scheduled_arrival"
    actualArrival: Date,
    wasTrackedUntilArrival: Bool
  ) {
    let duration = Int(max(0, actualArrival.timeIntervalSince(userSelectedDeparture)) / 60)

    telemetry.track(
      event: "journey_completed",
      properties: [
        "train_id": trainId,
        "from_station_id": from.id ?? from.code,
        "to_station_id": to.id ?? to.code,
        "journey_duration_actual_minutes": duration,
        "completion_type": completionType,
        "was_tracked_until_arrival": wasTrackedUntilArrival,
        "completed_at": iso8601String(actualArrival),
      ]
    )

    // Persist and evaluate round-trip
    let record = JourneyRecord(
      trainId: trainId,
      fromStationId: from.id ?? from.code,
      toStationId: to.id ?? to.code,
      completedAt: actualArrival
    )
    appendJourneyRecord(record)
    trackRoundTripIfApplicable(currentJourney: record)
  }

  /// Minimal completion tracking (e.g., from arrival screen without full context).
  func trackJourneyCompletedMinimal(
    destinationCode: String,
    destinationName: String,
    completionType: String = "arrival_screen"
  ) {
    telemetry.track(
      event: "journey_completed",
      properties: [
        "to_station_id": destinationCode,
        "to_station_name": destinationName,
        "completion_type": completionType,
        "completed_at": iso8601String(Date()),
      ]
    )
  }

  // MARK: - Round Trip

  func trackRoundTripIfApplicable(currentJourney: JourneyRecord) {
    let history = loadJourneyHistory()
    guard !history.isEmpty else { return }
    let windowStart =
      Calendar.current.date(
        byAdding: .day, value: -roundTripWindowDays, to: currentJourney.completedAt)
      ?? currentJourney.completedAt

    // Find last journey in the window
    let prior =
      history
      .filter { $0.completedAt >= windowStart && $0.completedAt <= currentJourney.completedAt }
      .sorted { $0.completedAt > $1.completedAt }
      .first

    guard let previous = prior else { return }

    let isReverseDirection =
      previous.fromStationId == currentJourney.toStationId
      && previous.toStationId == currentJourney.fromStationId

    let daysBetween =
      Calendar.current.dateComponents(
        [.day], from: previous.completedAt, to: currentJourney.completedAt
      ).day ?? 0

    telemetry.track(
      event: "round_trip_completed",
      properties: [
        "days_between_trips": daysBetween,
        "is_reverse_direction": isReverseDirection,
        "previous_journey_id":
          "\(previous.fromStationId)->\(previous.toStationId)@\(iso8601String(previous.completedAt))",
      ]
    )
  }

  #if DEBUG
    /// Test helper to evaluate round-trip detection without side effects.
    func _test_evaluateRoundTrip(
      currentJourney: JourneyRecord,
      history: [JourneyRecord]
    ) -> (isRoundTrip: Bool, isReverseDirection: Bool, daysBetween: Int)? {
      guard !history.isEmpty else { return nil }
      let windowStart =
        Calendar.current.date(
          byAdding: .day, value: -roundTripWindowDays, to: currentJourney.completedAt)
        ?? currentJourney.completedAt
      let prior =
        history
        .filter { $0.completedAt >= windowStart && $0.completedAt <= currentJourney.completedAt }
        .sorted { $0.completedAt > $1.completedAt }
        .first
      guard let previous = prior else { return nil }
      let isReverseDirection =
        previous.fromStationId == currentJourney.toStationId
        && previous.toStationId == currentJourney.fromStationId
      let daysBetween =
        Calendar.current.dateComponents(
          [.day], from: previous.completedAt, to: currentJourney.completedAt
        ).day ?? 0
      return (true, isReverseDirection, daysBetween)
    }
  #endif

  // MARK: - Engagement Events

  func trackTrainSearchInitiated() {
    telemetry.track(event: "train_search_initiated", properties: nil)
  }

  func trackStationSelected(station: Station, selectionType: String) {
    telemetry.track(
      event: "station_selected",
      properties: [
        "station_id": station.id ?? station.code,
        "station_name": station.name,
        "selection_type": selectionType,
      ]
    )
  }

  func trackTrainSelected(item: JourneyService.AvailableTrainItem) {
    telemetry.track(
      event: "train_selected",
      properties: [
        "train_id": item.trainId,
        "train_code": item.code,
        "train_name": item.name,
        "from_station_id": item.fromStationId,
        "to_station_id": item.toStationId,
        "departure_time": iso8601String(item.segmentDeparture),
        "arrival_time": iso8601String(item.segmentArrival),
      ]
    )
  }

  func trackArrivalConfirmed(stationCode: String, stationName: String) {
    telemetry.track(
      event: "arrival_confirmed",
      properties: [
        "station_code": stationCode,
        "station_name": stationName,
      ]
    )
  }

  // MARK: - Live Activity / Alarm

  func trackLiveActivityStateChanged(activityId: String, state: String, trainName: String) {
    telemetry.track(
      event: "live_activity_state_changed",
      properties: [
        "activity_id": activityId,
        "state": state,
        "train_name": trainName,
      ]
    )
  }

  func trackAlarmScheduled(
    activityId: String, arrivalTime: Date, offsetMinutes: Int, destinationCode: String
  ) {
    telemetry.track(
      event: "alarm_scheduled",
      properties: [
        "activity_id": activityId,
        "arrival_time": iso8601String(arrivalTime),
        "alarm_offset_minutes": offsetMinutes,
        "destination_code": destinationCode,
      ]
    )
  }

  func trackAlarmTriggered(activityId: String) {
    telemetry.track(
      event: "alarm_triggered",
      properties: [
        "activity_id": activityId,
        "triggered_at": iso8601String(Date()),
      ]
    )
  }

  func trackAlarmConfigured(
    offsetMinutes: Int,
    isValid: Bool,
    validationFailureReason: String?
  ) {
    var properties: [String: Any] = [
      "alarm_offset_minutes": offsetMinutes,
      "is_valid": isValid,
      "configured_at": iso8601String(Date()),
    ]
    
    if let reason = validationFailureReason {
      properties["validation_failure_reason"] = reason
    }
    
    telemetry.track(
      event: "alarm_configured",
      properties: properties
    )
  }

  // MARK: - Technical

  func trackDeepLinkOpened(urlString: String, params: [String: String]) {
    var props: [String: Any] = ["url": urlString]
    for (k, v) in params { props[k] = v }
    telemetry.track(event: "deep_link_opened", properties: props)
  }

  func trackNotificationInteraction(identifier: String?, category: String?, action: String?) {
    telemetry.track(
      event: "notification_interaction",
      properties: [
        "notification_identifier": identifier as Any,
        "category": category as Any,
        "action": action as Any,
      ]
    )
  }

  // MARK: - History Storage

  private func loadJourneyHistory() -> [JourneyRecord] {
    guard let data = userDefaults.data(forKey: StorageKeys.journeyHistory) else { return [] }
    if let decoded = try? decoder.decode([JourneyRecord].self, from: data) { return decoded }
    return []
  }

  private func saveJourneyHistory(_ history: [JourneyRecord]) {
    if let data = try? encoder.encode(history) {
      userDefaults.set(data, forKey: StorageKeys.journeyHistory)
    }
  }

  private func appendJourneyRecord(_ record: JourneyRecord) {
    var history = loadJourneyHistory()
    history.insert(record, at: 0)
    if history.count > maxStoredJourneys { history = Array(history.prefix(maxStoredJourneys)) }
    saveJourneyHistory(history)
  }

  // MARK: - Helpers

  private func iso8601String(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }
}
