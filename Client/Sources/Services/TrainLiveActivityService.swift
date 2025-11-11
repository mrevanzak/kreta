import ActivityKit
import AlarmKit
import ConvexMobile
import Foundation
import OSLog

// MARK: - TrainLiveActivityService

final class TrainLiveActivityService: @unchecked Sendable {
  static let shared = TrainLiveActivityService()

  // MARK: - Constants

  private enum Constants {
    static let maxRetryAttempts = 3
    static let baseRetryDelay: Double = 0.5
    static let nanosecondsPerSecond: UInt64 = 1_000_000_000
  }

  // MARK: - Properties

  private let convexClient: ConvexClient
  private let lockQueue = DispatchQueue(label: "com.kreta.liveActivityService.queue")
  private let logger = Logger(subsystem: "kreta", category: "TrainLiveActivityService")
  private var _hasStartedGlobalMonitoring = false
  private var _transitionTimers: [String: Task<Void, Never>] = [:]

  private var hasStartedGlobalMonitoring: Bool {
    get { lockQueue.sync { _hasStartedGlobalMonitoring } }
    set { lockQueue.sync { _hasStartedGlobalMonitoring = newValue } }
  }

  private var transitionTimers: [String: Task<Void, Never>] {
    get { lockQueue.sync { _transitionTimers } }
    set { lockQueue.sync { _transitionTimers = newValue } }
  }

  private init(
    convexClient: ConvexClient = Dependencies.shared.convexClient
  ) {
    self.convexClient = convexClient
  }

  // MARK: - Activity Lifecycle

  @discardableResult
  @MainActor
  func start(
    trainName: String,
    from: TrainStation,
    destination: TrainStation,
    // seatClass: SeatClass,
    // seatNumber: String,
    initialJourneyState: JourneyState? = nil
  ) async throws -> Activity<TrainActivityAttributes> {
    let activity = try await createActivity(
      trainName: trainName,
      from: from,
      destination: destination,
      // seatClass: seatClass,
      // seatNumber: seatNumber,
      initialJourneyState: initialJourneyState
    )

    await setupActivityMonitoring(for: activity, destination: destination, trainName: trainName)

    return activity
  }

  @MainActor
  private func createActivity(
    trainName: String,
    from: TrainStation,
    destination: TrainStation,
    // seatClass: SeatClass,
    // seatNumber: String,
    initialJourneyState: JourneyState? = nil
  ) async throws -> Activity<TrainActivityAttributes> {
    let attributes = TrainActivityAttributes(
      trainName: trainName,
      from: from,
      destination: destination,
      // seatClass: seatClass,
      // seatNumber: seatNumber
    )

    let initialState = initialJourneyState ?? .beforeBoarding
    let contentState = TrainActivityAttributes.ContentState(journeyState: initialState)
    let content = ActivityContent(state: contentState, staleDate: nil)

    return try Activity<TrainActivityAttributes>.request(
      attributes: attributes,
      content: content
    )
  }

  @MainActor
  private func setupActivityMonitoring(
    for activity: Activity<TrainActivityAttributes>,
    destination: TrainStation,
    trainName: String
  ) async {
    let activityId = activity.id
    let alarmEnabled = AlarmPreferences.shared.defaultAlarmEnabled
    let alarmOffsetMinutes = AlarmPreferences.shared.defaultAlarmOffsetMinutes

    logger.info("Starting Live Activity setup for train: \(trainName, privacy: .public)")
    logger.debug("Activity ID: \(activityId, privacy: .public)")
    logger.debug("Alarm enabled: \(alarmEnabled), offset: \(alarmOffsetMinutes) minutes")

    // Safety: if departure is already in the past and state is still beforeBoarding,
    // immediately transition to onBoard to reflect in-progress journeys.
    if let departure = activity.attributes.from.estimatedTime,
      departure <= Date(),
      activity.content.state.journeyState == .beforeBoarding
    {
      await transitionToOnBoard(activityId: activityId)
    }

    Task {
      logger.info("Starting automatic transitions for activity \(activityId, privacy: .public)")
      await startAutomaticTransitions(for: activity)
      logger.info("Automatic transitions started for activity \(activityId, privacy: .public)")
    }

    Task {
      logger.info("Scheduling alarm for activity \(activityId, privacy: .public)")
      await scheduleAlarmIfEnabled(
        activityId: activityId,
        alarmEnabled: alarmEnabled,
        alarmOffsetMinutes: alarmOffsetMinutes,
        arrivalTime: destination.estimatedTime,
        trainName: trainName,
        destinationName: destination.name,
        destinationCode: destination.code
      )
      logger.info("Alarm scheduling complete for activity \(activityId, privacy: .public)")
    }

    Task {
      await scheduleServerArrivalAlert(trainName: trainName, destination: destination)
    }

    Task {
      await scheduleServerStateUpdates(
        activityId: activityId,
        trainName: trainName,
        origin: activity.attributes.from,
        destination: destination,
        arrivalLeadMinutes: Double(alarmOffsetMinutes)
      )
    }
  }

  @MainActor
  func update(
    activityId: String,
    journeyState: JourneyState? = nil
  ) async {
    guard let activity = findActivity(with: activityId) else { return }

    let contentState = activity.content.state
    let newContentState = TrainActivityAttributes.ContentState(
      journeyState: journeyState ?? contentState.journeyState,
    )
    await activity.update(ActivityContent(state: newContentState, staleDate: nil))
  }

  func getActiveLiveActivities() -> [Activity<TrainActivityAttributes>] {
    Activity<TrainActivityAttributes>.activities
  }

  private func findActivity(with activityId: String) -> Activity<TrainActivityAttributes>? {
    Activity<TrainActivityAttributes>.activities.first { $0.id == activityId }
  }

  @MainActor
  func refreshInForeground(currentDate: Date = Date()) async {
    logger.info("Refreshing Live Activities after foreground entry")

    for activity in Activity<TrainActivityAttributes>.activities {
      var currentState = activity.content.state.journeyState

      if currentState == .beforeBoarding,
        let departureTime = activity.attributes.from.estimatedTime,
        departureTime <= currentDate
      {
        logger.debug(
          "Foreground refresh transitioning activity \(activity.id, privacy: .public) to onBoard"
        )
        await transitionToOnBoard(activityId: activity.id)
        currentState = .onBoard
      }

      if currentState != .prepareToDropOff,
        let arrivalTime = activity.attributes.destination.estimatedTime,
        arrivalTime <= currentDate
      {
        logger.debug(
          "Foreground refresh transitioning activity \(activity.id, privacy: .public) to prepareToDropOff"
        )
        await transitionToPrepareToDropOff(activityId: activity.id)
        currentState = .prepareToDropOff
      }

      await rescheduleAlarmIfNeeded(for: activity)
    }
  }

  @MainActor
  func transitionToOnBoard(activityId: String) async {
    await update(activityId: activityId, journeyState: .onBoard)
    if let activity = findActivity(with: activityId) {
      AnalyticsEventService.shared.trackLiveActivityStateChanged(
        activityId: activityId,
        state: "onBoard",
        trainName: activity.attributes.trainName
      )
    }
  }

  @MainActor
  func transitionToPrepareToDropOff(activityId: String) async {
    await update(activityId: activityId, journeyState: .prepareToDropOff)
    if let activity = findActivity(with: activityId) {
      AnalyticsEventService.shared.trackLiveActivityStateChanged(
        activityId: activityId,
        state: "prepareToDropOff",
        trainName: activity.attributes.trainName
      )
    }
  }

  // MARK: - State Transitions

  @MainActor
  func startAutomaticTransitions(for activity: Activity<TrainActivityAttributes>) async {
    let activityId = activity.id

    lockQueue.sync {
      _transitionTimers[activityId]?.cancel()
    }

    let timerTask = Task<Void, Never> { @MainActor in
      defer {
        _ = lockQueue.sync { _transitionTimers.removeValue(forKey: activityId) }
      }

      await scheduleDepartureTransition(for: activity)
    }

    lockQueue.sync {
      _transitionTimers[activityId] = timerTask
    }
  }

  @MainActor
  private func scheduleDepartureTransition(
    for activity: Activity<TrainActivityAttributes>
  ) async {
    guard let departureTime = activity.attributes.from.estimatedTime else { return }

    let delay = max(0, departureTime.timeIntervalSinceNow)
    guard delay > 0 else { return }

    let delayNanoseconds = UInt64(delay * Double(Constants.nanosecondsPerSecond))
    try? await Task.sleep(nanoseconds: delayNanoseconds)
    await transitionToOnBoard(activityId: activity.id)
  }

  // MARK: - Alarm Management

  private func scheduleAlarmIfEnabled(
    activityId: String,
    alarmEnabled: Bool,
    alarmOffsetMinutes: Int,
    arrivalTime: Date?,
    trainName: String,
    destinationName: String,
    destinationCode: String
  ) async {
    logger.debug("scheduleAlarmIfEnabled called for activity \(activityId, privacy: .public)")
    logger.debug(
      "Alarm enabled: \(alarmEnabled), offset: \(alarmOffsetMinutes) minutes"
    )

    guard alarmEnabled else {
      logger.info(
        "Alarm disabled for activity \(activityId, privacy: .public), skipping alarm scheduling")
      return
    }

    guard let arrivalTime = arrivalTime else {
      logger.warning(
        "No arrival time for activity \(activityId, privacy: .public), skipping alarm scheduling")
      return
    }

    logger.info("Scheduling alarm for activity \(activityId, privacy: .public)")
    logger.debug(
      "Train: \(trainName, privacy: .public), Destination: \(destinationName, privacy: .public) (\(destinationCode, privacy: .public))"
    )
    logger.debug("Arrival time: \(arrivalTime, privacy: .public)")

    do {
      try await TrainAlarmService.shared.scheduleArrivalAlarm(
        activityId: activityId,
        arrivalTime: arrivalTime,
        offsetMinutes: alarmOffsetMinutes,
        trainName: trainName,
        destinationName: destinationName,
        destinationCode: destinationCode
      )
      logger.info("Successfully scheduled alarm for activity \(activityId, privacy: .public)")
      AnalyticsEventService.shared.trackAlarmScheduled(
        activityId: activityId,
        arrivalTime: arrivalTime,
        offsetMinutes: alarmOffsetMinutes,
        destinationCode: destinationCode
      )
    } catch {
      logger.error(
        "Failed to schedule alarm for activity \(activityId, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      if let alarmError = error as? TrainAlarmError {
        logger.debug(
          "AlarmKit error: \(alarmError.errorDescription ?? "Unknown", privacy: .public)")
      }
    }
  }

  private func scheduleAlarmIfEnabled(for activity: Activity<TrainActivityAttributes>) async {
    let alarmEnabled = AlarmPreferences.shared.defaultAlarmEnabled
    let alarmOffsetMinutes = AlarmPreferences.shared.defaultAlarmOffsetMinutes

    await scheduleAlarmIfEnabled(
      activityId: activity.id,
      alarmEnabled: alarmEnabled,
      alarmOffsetMinutes: alarmOffsetMinutes,
      arrivalTime: activity.attributes.destination.estimatedTime,
      trainName: activity.attributes.trainName,
      destinationName: activity.attributes.destination.name,
      destinationCode: activity.attributes.destination.code
    )
  }

  @MainActor
  func end(
    activityId: String,
    dismissalPolicy: ActivityUIDismissalPolicy = .immediate
  ) async {
    cancelTimer(for: activityId)
    await TrainAlarmService.shared.cancelArrivalAlarm(activityId: activityId)

    guard let activity = findActivity(with: activityId) else { return }
    await activity.end(nil, dismissalPolicy: dismissalPolicy)
  }

  @MainActor
  func endAllImmediately() async {
    cancelAllTimers()
    await TrainAlarmService.shared.cancelAllAlarms()

    for activity in Activity<TrainActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private func cancelTimer(for activityId: String) {
    lockQueue.sync {
      _transitionTimers[activityId]?.cancel()
      _transitionTimers.removeValue(forKey: activityId)
    }
  }

  private func cancelAllTimers() {
    let timers = lockQueue.sync { Array(_transitionTimers.values) }
    timers.forEach { $0.cancel() }
    lockQueue.sync {
      _transitionTimers.removeAll()
    }
  }

  // MARK: - Monitoring

  private func monitorPushTokens(for activity: Activity<TrainActivityAttributes>) async {
    for await tokenData in activity.pushTokenUpdates {
      let token = tokenData.hexEncodedString()
      await registerLiveActivityToken(activityId: activity.id, token: token)
    }
  }

  // MARK: - Server Arrival Alert Scheduling

  private func scheduleServerArrivalAlert(
    trainName: String,
    destination: TrainStation
  ) async {
    guard let deviceToken = PushRegistrationService.shared.currentToken() else {
      logger.debug("No device token available; skipping server arrival alert scheduling")
      return
    }

    guard let arrivalTime = destination.estimatedTime else {
      logger.debug("No destination ETA; skipping server arrival alert scheduling")
      return
    }

    let arrivalMs = Double(arrivalTime.timeIntervalSince1970 * 1000)

    do {
      let _: String = try await convexClient.mutation(
        "notifications:scheduleArrivalAlert",
        with: [
          "deviceToken": deviceToken,
          "trainId": nil as String?,
          "trainName": trainName,
          "arrivalTime": arrivalMs,
          "destinationStation": [
            "name": destination.name,
            "code": destination.code,
            "estimatedTime": arrivalMs,
          ],
        ],
        captureTelemetry: true
      )
      logger.info("Scheduled server arrival alert for \(destination.name, privacy: .public)")
    } catch {
      logger.error(
        "Failed to schedule server arrival alert: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func scheduleServerStateUpdates(
    activityId: String,
    trainName: String,
    origin: TrainStation,
    destination: TrainStation,
    arrivalLeadMinutes: Double
  ) async {
    let departureTimeMs = origin.estimatedTime.map { Double($0.timeIntervalSince1970 * 1000) }
    let arrivalTimeMs = destination.estimatedTime.map { Double($0.timeIntervalSince1970 * 1000) }

    guard departureTimeMs != nil || arrivalTimeMs != nil else {
      logger.debug(
        "No schedule metadata for activity \(activityId, privacy: .public); skipping server state scheduling"
      )
      return
    }

    struct ScheduleResponse: Decodable {
      let departureScheduled: Bool
      let arrivalScheduled: Bool
    }

    let arrivalLeadMs = max(0, arrivalLeadMinutes) * 60 * 1000

    do {
      let response: ScheduleResponse = try await convexClient.mutation(
        "liveActivities:scheduleStateUpdates",
        with: [
          "activityId": activityId,
          "trainName": trainName,
          "departureTime": departureTimeMs,
          "arrivalTime": arrivalTimeMs,
          "arrivalLeadTimeMs": arrivalLeadMs,
        ],
        captureTelemetry: true
      )
      logger.info(
        "Server scheduling for activity \(activityId, privacy: .public) -> departure: \(response.departureScheduled), arrival: \(response.arrivalScheduled)"
      )
    } catch {
      logger.error(
        "Failed to schedule server state updates for activity \(activityId, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  @MainActor
  func startGlobalMonitoring() async {
    guard !hasStartedGlobalMonitoring else { return }
    hasStartedGlobalMonitoring = true

    Task { await monitorExistingActivities() }
    Task { await monitorActivityUpdates() }
    Task { await monitorPushToStartTokens() }
    Task { await monitorAlarmUpdates() }
  }

  private func monitorExistingActivities() async {
    for activity in Activity<TrainActivityAttributes>.activities {
      await monitorPushTokens(for: activity)
      await rescheduleAlarmIfNeeded(for: activity)
    }
  }

  private func rescheduleAlarmIfNeeded(for activity: Activity<TrainActivityAttributes>) async {
    let alarmEnabled = AlarmPreferences.shared.defaultAlarmEnabled
    guard alarmEnabled else { return }
    guard activity.attributes.destination.estimatedTime != nil else { return }

    let hasAlarm = TrainAlarmService.shared.hasScheduledAlarm(activityId: activity.id)
    guard !hasAlarm else { return }

    await scheduleAlarmIfEnabled(for: activity)
  }

  private func monitorActivityUpdates() async {
    for await activity in Activity<TrainActivityAttributes>.activityUpdates {
      await monitorPushTokens(for: activity)
    }
  }

  // MARK: - Token Registration

  private func registerLiveActivityToken(activityId: String, token: String) async {
    await performWithRetry {
      guard let deviceToken = PushRegistrationService.shared.currentToken() else {
        throw TokenRegistrationError.missingDeviceToken
      }

      let _: String = try await self.convexClient.mutation(
        "registrations:registerLiveActivityToken",
        with: [
          "activityId": activityId,
          "token": token,
          "deviceToken": deviceToken,
        ],
        captureTelemetry: true
      )
    }
  }

  private func monitorPushToStartTokens() async {
    for await tokenData in Activity<TrainActivityAttributes>.pushToStartTokenUpdates {
      let token = tokenData.hexEncodedString()
      await registerLiveActivityStartToken(token: token)
    }
  }

  private func registerLiveActivityStartToken(token: String) async {
    await performWithRetry {
      guard let deviceToken = PushRegistrationService.shared.currentToken() else {
        throw TokenRegistrationError.missingDeviceToken
      }

      let _: String = try await self.convexClient.mutation(
        "registrations:registerLiveActivityStartToken",
        with: [
          "deviceToken": deviceToken,
          "token": token,
          "userId": nil,
        ],
        captureTelemetry: true
      )
    }
  }

  private func performWithRetry(_ operation: @escaping () async throws -> Void) async {
    for attempt in 1...Constants.maxRetryAttempts {
      do {
        try await operation()
        return
      } catch {
        guard attempt < Constants.maxRetryAttempts else { return }

        let delayNanoseconds = calculateRetryDelay(for: attempt)
        try? await Task.sleep(nanoseconds: delayNanoseconds)
      }
    }
  }

  private func calculateRetryDelay(for attempt: Int) -> UInt64 {
    let exponentialDelay = pow(2.0, Double(attempt)) * Constants.baseRetryDelay
    return UInt64(exponentialDelay * Double(Constants.nanosecondsPerSecond))
  }

  private func monitorAlarmUpdates() async {
    for await alarms in AlarmManager.shared.alarmUpdates {
      for alarm in alarms {
        guard alarm.state == .alerting else { continue }
        guard let activityId = TrainAlarmService.shared.activityId(for: alarm.id) else {
          continue
        }

        await handleAlarmTriggered(for: activityId)
      }
    }
  }

  @MainActor
  private func handleAlarmTriggered(for activityId: String) async {
    guard findActivity(with: activityId) != nil else {
      logger.warning(
        "Activity \(activityId, privacy: .public) no longer exists, skipping transition")
      return
    }

    AnalyticsEventService.shared.trackAlarmTriggered(activityId: activityId)
    await transitionToPrepareToDropOff(activityId: activityId)
    logger.info(
      "Automatically transitioned activity \(activityId, privacy: .public) to .prepareToDropOff due to alarm"
    )
  }
}

// MARK: - Errors

private enum TokenRegistrationError: Error {
  case missingDeviceToken
}
