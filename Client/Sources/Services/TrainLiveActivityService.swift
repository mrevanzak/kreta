@preconcurrency import ActivityKit
import AlarmKit
import ConvexMobile
import Foundation
import OSLog

// MARK: - LiveActivityRegistry

actor LiveActivityRegistry {
  private struct AlarmSnapshot: Equatable {
    let arrivalTime: Date
    let offsetMinutes: Int
    let alarmEnabled: Bool
  }

  private var hasStartedMonitoring = false
  private var timers: [String: Task<Void, Never>] = [:]
  private var alarmSnapshots: [String: AlarmSnapshot] = [:]

  func startMonitoringIfNeeded() -> Bool {
    guard !hasStartedMonitoring else { return false }
    hasStartedMonitoring = true
    return true
  }

  func storeTimer(_ task: Task<Void, Never>, for activityId: String) -> Task<Void, Never>? {
    let existing = timers[activityId]
    timers[activityId] = task
    return existing
  }

  func removeTimer(for activityId: String) -> Task<Void, Never>? {
    timers.removeValue(forKey: activityId)
  }

  func drainTimers() -> [Task<Void, Never>] {
    let all = Array(timers.values)
    timers.removeAll()
    return all
  }

  func shouldScheduleAlarm(
    activityId: String,
    arrivalTime: Date,
    offsetMinutes: Int,
    alarmEnabled: Bool,
    force: Bool = false
  ) -> Bool {
    guard alarmEnabled else {
      alarmSnapshots.removeValue(forKey: activityId)
      return false
    }

    let snapshot = AlarmSnapshot(
      arrivalTime: arrivalTime,
      offsetMinutes: offsetMinutes,
      alarmEnabled: alarmEnabled
    )

    if force {
      alarmSnapshots[activityId] = snapshot
      return true
    }

    guard alarmSnapshots[activityId] != snapshot else { return false }
    alarmSnapshots[activityId] = snapshot
    return true
  }

  func clearAlarmSnapshot(for activityId: String) {
    alarmSnapshots.removeValue(forKey: activityId)
  }
}

// MARK: - TrainLiveActivityService

final class TrainLiveActivityService: @unchecked Sendable {
  static let shared = TrainLiveActivityService()

  // MARK: - Constants

  enum Constants {
    static let maxRetryAttempts = 3
    static let baseRetryDelay: Double = 0.5
    static let nanosecondsPerSecond: UInt64 = 1_000_000_000
    static let retryJitterNanoseconds: UInt64 = 50_000_000
  }

  // MARK: - Properties

  private let convexClient: ConvexClient
  private let logger = Logger(subsystem: "kreta", category: "TrainLiveActivityService")
  private let stateRegistry = LiveActivityRegistry()

  private init(
    convexClient: ConvexClient = Dependencies.shared.convexClient
  ) {
    self.convexClient = convexClient
  }

  // MARK: - Activity Lifecycle

  @MainActor
  func start(
    trainName: String,
    from: TrainStation,
    destination: TrainStation,
    // seatClass: SeatClass,
    // seatNumber: String,
    initialJourneyState: JourneyState? = nil,
    alarmOffsetMinutes: Int = AlarmPreferences.shared.defaultAlarmOffsetMinutes
  ) async throws -> Activity<TrainActivityAttributes> {
    let activity = try await createActivity(
      trainName: trainName,
      from: from,
      destination: destination,
      // seatClass: seatClass,
      // seatNumber: seatNumber,
      initialJourneyState: initialJourneyState
    )

    await setupActivityMonitoring(
      for: activity,
      destination: destination,
      trainName: trainName,
      alarmOffsetMinutes: alarmOffsetMinutes
    )

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
      content: content,
      pushType: .token
    )
  }

  @MainActor
  private func setupActivityMonitoring(
    for activity: Activity<TrainActivityAttributes>,
    destination: TrainStation,
    trainName: String,
    alarmOffsetMinutes: Int = AlarmPreferences.shared.defaultAlarmOffsetMinutes
  ) async {
    let activityId = activity.id
    let alarmEnabled = AlarmPreferences.shared.defaultAlarmEnabled

    logger.info("Starting Live Activity setup for train: \(trainName, privacy: .public)")
    logger.debug("Activity ID: \(activityId, privacy: .public)")
    logger.debug("Alarm enabled: \(alarmEnabled), offset: \(alarmOffsetMinutes) minutes")

    logger.info("Monitoring push tokens for activity \(activityId, privacy: .public)")
    startMonitoringPushTokens(for: activity)

    // Safety: if departure is already in the past and state is still beforeBoarding,
    // immediately transition to onBoard to reflect in-progress journeys.
    if let departure = activity.attributes.from.estimatedTime,
      departure <= Date(),
      activity.content.state.journeyState == .beforeBoarding
    {
      await transitionToOnBoard(activityId: activityId)
    }

    logger.info("Starting automatic transitions for activity \(activityId, privacy: .public)")
    await startAutomaticTransitions(for: activity)
    logger.info("Automatic transitions started for activity \(activityId, privacy: .public)")

    runBackgroundJob(label: "scheduleAlarm") { service in
      await service.scheduleAlarmIfEnabled(
        activityId: activityId,
        alarmEnabled: alarmEnabled,
        alarmOffsetMinutes: alarmOffsetMinutes,
        arrivalTime: destination.estimatedTime,
        departureTime: activity.attributes.from.estimatedTime,
        trainName: trainName,
        destinationName: destination.name,
        destinationCode: destination.code
      )
    }

    runBackgroundJob(label: "scheduleServerArrival") { service in
      await service.scheduleServerArrivalAlert(trainName: trainName, destination: destination)
    }

    runBackgroundJob(label: "scheduleServerState") { service in
      await service.scheduleServerStateUpdates(
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
        let departureTime = activity.attributes.from.estimatedTime
      {
        // Normalize arrival time to handle next-day arrivals
        let normalizedArrival = Date.normalizeArrivalTime(
          arrival: arrivalTime, relativeTo: departureTime)
        if normalizedArrival <= currentDate {
          logger.debug(
            "Foreground refresh transitioning activity \(activity.id, privacy: .public) to prepareToDropOff"
          )
          await transitionToPrepareToDropOff(activityId: activity.id)
          currentState = .prepareToDropOff
        }
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
    let timerTask = Task<Void, Never> { @MainActor [weak self] in
      guard let self else { return }
      await self.scheduleDepartureTransition(for: activityId)
      await self.stateRegistry.removeTimer(for: activityId)
    }

    let previousTimer = await stateRegistry.storeTimer(timerTask, for: activityId)
    previousTimer?.cancel()
  }

  @MainActor
  private func scheduleDepartureTransition(
    for activityId: String
  ) async {
    guard let activity = findActivity(with: activityId) else { return }
    guard let departureTime = activity.attributes.from.estimatedTime else { return }

    let delay = max(0, departureTime.timeIntervalSinceNow)
    guard delay > 0 else {
      await transitionToOnBoard(activityId: activityId)
      return
    }

    let delayNanoseconds = UInt64(delay * Double(Constants.nanosecondsPerSecond))
    do {
      try await Task.sleep(nanoseconds: delayNanoseconds)
    } catch is CancellationError {
      logger.debug(
        "Departure transition timer cancelled for activity \(activityId, privacy: .public)")
      return
    } catch {
      logger.error(
        "Departure transition timer failed for activity \(activityId, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      return
    }

    guard !Task.isCancelled else { return }
    await transitionToOnBoard(activityId: activityId)
  }

  // MARK: - Alarm Management

  private func scheduleAlarmIfEnabled(
    activityId: String,
    alarmEnabled: Bool,
    alarmOffsetMinutes: Int,
    arrivalTime: Date?,
    departureTime: Date? = nil,
    trainName: String,
    destinationName: String,
    destinationCode: String,
    force: Bool = false
  ) async {
    guard !Task.isCancelled else {
      logger.debug(
        "Skipping alarm scheduling for \(activityId, privacy: .public) due to cancellation")
      return
    }
    logger.debug("scheduleAlarmIfEnabled called for activity \(activityId, privacy: .public)")
    logger.debug(
      "Alarm enabled: \(alarmEnabled), offset: \(alarmOffsetMinutes) minutes"
    )

    guard alarmEnabled else {
      await stateRegistry.clearAlarmSnapshot(for: activityId)
      logger.info(
        "Alarm disabled for activity \(activityId, privacy: .public), skipping alarm scheduling")
      return
    }

    guard let arrivalTime = arrivalTime else {
      await stateRegistry.clearAlarmSnapshot(for: activityId)
      logger.warning(
        "No arrival time for activity \(activityId, privacy: .public), skipping alarm scheduling")
      return
    }

    guard
      await stateRegistry.shouldScheduleAlarm(
        activityId: activityId,
        arrivalTime: arrivalTime,
        offsetMinutes: alarmOffsetMinutes,
        alarmEnabled: alarmEnabled,
        force: force
      )
    else {
      logger.debug(
        "Skipping alarm scheduling for activity \(activityId, privacy: .public); parameters unchanged"
      )
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
        destinationCode: destinationCode,
        departureTime: departureTime
      )
      logger.info("Successfully scheduled alarm for activity \(activityId, privacy: .public)")
      AnalyticsEventService.shared.trackAlarmScheduled(
        activityId: activityId,
        arrivalTime: arrivalTime,
        offsetMinutes: alarmOffsetMinutes,
        destinationCode: destinationCode
      )
    } catch {
      await stateRegistry.clearAlarmSnapshot(for: activityId)
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
      departureTime: activity.attributes.from.estimatedTime,
      trainName: activity.attributes.trainName,
      destinationName: activity.attributes.destination.name,
      destinationCode: activity.attributes.destination.code
    )
  }

  // MARK: - Concurrency Helpers

  @discardableResult
  private func runBackgroundJob(
    label: StaticString,
    priority: TaskPriority = .background,
    operation: @escaping @Sendable (TrainLiveActivityService) async -> Void
  ) -> Task<Void, Never> {
    Task(priority: priority) { [weak self] in
      guard let self else { return }
      self.logger.debug("Starting job \(label, privacy: .public)")
      defer { self.logger.debug("Finished job \(label, privacy: .public)") }
      guard !Task.isCancelled else {
        self.logger.debug("Skipping job \(label, privacy: .public) due to cancellation")
        return
      }
      await operation(self)
    }
  }

  @MainActor
  func end(
    activityId: String,
    dismissalPolicy: ActivityUIDismissalPolicy = .immediate
  ) async {
    await cancelTimer(for: activityId)
    await stateRegistry.clearAlarmSnapshot(for: activityId)
    await TrainAlarmService.shared.cancelArrivalAlarm(activityId: activityId)

    guard let activity = findActivity(with: activityId) else { return }
    await activity.end(nil, dismissalPolicy: dismissalPolicy)
  }

  @MainActor
  func endAllImmediately() async {
    await cancelAllTimers()
    await TrainAlarmService.shared.cancelAllAlarms()

    for activity in Activity<TrainActivityAttributes>.activities {
      await stateRegistry.clearAlarmSnapshot(for: activity.id)
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private func cancelTimer(for activityId: String) async {
    let timer = await stateRegistry.removeTimer(for: activityId)
    timer?.cancel()
  }

  private func cancelAllTimers() async {
    let timers = await stateRegistry.drainTimers()
    timers.forEach { $0.cancel() }
  }

  // MARK: - Monitoring

  // MARK: - Server Arrival Alert Scheduling

  private func scheduleServerArrivalAlert(
    trainName: String,
    destination: TrainStation
  ) async {
    guard !Task.isCancelled else { return }
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
    guard !Task.isCancelled else { return }
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
    guard await stateRegistry.startMonitoringIfNeeded() else { return }

    runBackgroundJob(label: "monitorExistingActivities", priority: .utility) { service in
      await service.monitorExistingActivities()
    }

    runBackgroundJob(label: "monitorPushToStartTokens") { service in
      await service.monitorPushToStartTokens()
    }

    runBackgroundJob(label: "monitorAlarmUpdates") { service in
      await service.monitorAlarmUpdates()
    }
  }

  @MainActor
  private func monitorExistingActivities() async {
    for activity in Activity<TrainActivityAttributes>.activities {
      startMonitoringPushTokens(for: activity)
      await rescheduleAlarmIfNeeded(for: activity)
    }
  }

  @MainActor
  func refreshAlarmConfiguration(alarmOffsetMinutes: Int) async {
    let activities = Activity<TrainActivityAttributes>.activities
    logger.info(
      "Refreshing alarm configuration for \(activities.count, privacy: .public) active activities"
    )

    for activity in activities {
      await TrainAlarmService.shared.cancelArrivalAlarm(activityId: activity.id)
      await stateRegistry.clearAlarmSnapshot(for: activity.id)
    }

    let alarmEnabled = AlarmPreferences.shared.defaultAlarmEnabled
    guard alarmEnabled else {
      logger.info("Default alarm disabled; skipping reschedule for active activities")
      return
    }

    for activity in activities {
      startMonitoringPushTokens(for: activity)

      await scheduleAlarmIfEnabled(
        activityId: activity.id,
        alarmEnabled: alarmEnabled,
        alarmOffsetMinutes: alarmOffsetMinutes,
        arrivalTime: activity.attributes.destination.estimatedTime,
        departureTime: activity.attributes.from.estimatedTime,
        trainName: activity.attributes.trainName,
        destinationName: activity.attributes.destination.name,
        destinationCode: activity.attributes.destination.code
      )

      await scheduleServerStateUpdates(
        activityId: activity.id,
        trainName: activity.attributes.trainName,
        origin: activity.attributes.from,
        destination: activity.attributes.destination,
        arrivalLeadMinutes: Double(alarmOffsetMinutes)
      )
    }
  }

  private func startMonitoringPushTokens(for activity: Activity<TrainActivityAttributes>) {
    let activityId = activity.id

    runBackgroundJob(label: "monitorPushTokens", priority: .utility) { service in
      await service.monitorPushTokens(activityId: activityId)
    }
  }

  @MainActor
  private func monitorPushTokens(activityId: String) async {
    guard let activity = findActivity(with: activityId) else { return }

    // CRITICAL: Register the current token if it exists before monitoring for changes.
    // pushTokenUpdates only emits when the token CHANGES, not the initial value.
    if let currentToken = activity.pushToken {
      logger.info(
        "Registering existing push token for activity \(activityId, privacy: .public)")
      let token = currentToken.hexEncodedString()
      await registerLiveActivityToken(activityId: activityId, token: token)
    } else {
      logger.warning(
        "Activity \(activityId, privacy: .public) has no push token yet, waiting for updates"
      )
    }

    // Continue monitoring for token changes
    for await tokenData in activity.pushTokenUpdates {
      if Task.isCancelled { break }
      logger.info("Received push token update for activity \(activityId, privacy: .public)")
      let token = tokenData.hexEncodedString()
      await registerLiveActivityToken(activityId: activityId, token: token)
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

  // MARK: - Token Registration

  private func registerLiveActivityToken(activityId: String, token: String) async {
    await performWithRetry(label: "registerLiveActivityToken") {
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
    // CRITICAL: Register the current push-to-start token if it exists.
    // pushToStartTokenUpdates only emits when the token CHANGES, not the initial value.
    if let currentToken = Activity<TrainActivityAttributes>.pushToStartToken {
      logger.info("Registering existing push-to-start token")
      let token = currentToken.hexEncodedString()
      await registerLiveActivityStartToken(token: token)
    } else {
      logger.warning("No push-to-start token available yet, waiting for updates")
    }

    // Continue monitoring for token changes
    for await tokenData in Activity<TrainActivityAttributes>.pushToStartTokenUpdates {
      if Task.isCancelled { break }
      logger.info("Received push-to-start token update")
      let token = tokenData.hexEncodedString()
      await registerLiveActivityStartToken(token: token)
    }
  }

  private func registerLiveActivityStartToken(token: String) async {
    await performWithRetry(label: "registerLiveActivityStartToken") {
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

  private func performWithRetry(
    label: StaticString,
    operation: @escaping () async throws -> Void
  ) async {
    for attempt in 1...Constants.maxRetryAttempts {
      if Task.isCancelled {
        logger.debug("\(label, privacy: .public) cancelled before attempt \(attempt)")
        return
      }

      do {
        logger.debug("\(label, privacy: .public) attempt \(attempt) started")
        try await operation()
        logger.debug("\(label, privacy: .public) succeeded on attempt \(attempt)")
        return
      } catch is CancellationError {
        logger.debug("\(label, privacy: .public) cancelled during attempt \(attempt)")
        return
      } catch {
        logger.error(
          "\(label, privacy: .public) attempt \(attempt) failed: \(error.localizedDescription, privacy: .public)"
        )
        guard attempt < Constants.maxRetryAttempts else {
          logger.error("\(label, privacy: .public) exhausted retry attempts")
          return
        }

        let delayNanoseconds = calculateRetryDelay(for: attempt)
        logger.debug(
          "\(label, privacy: .public) retrying in \(delayNanoseconds) nanoseconds"
        )
        do {
          try await Task.sleep(nanoseconds: delayNanoseconds)
        } catch is CancellationError {
          logger.debug("\(label, privacy: .public) retry sleep cancelled")
          return
        } catch {
          logger.error(
            "\(label, privacy: .public) retry sleep failed: \(error.localizedDescription, privacy: .public)"
          )
          return
        }
      }
    }
  }

  func calculateRetryDelay(for attempt: Int) -> UInt64 {
    let exponentialDelay = pow(2.0, Double(attempt)) * Constants.baseRetryDelay
    let baseDelay = UInt64(exponentialDelay * Double(Constants.nanosecondsPerSecond))
    let jitter = UInt64.random(in: 0...Constants.retryJitterNanoseconds)
    return baseDelay + jitter
  }

  private func monitorAlarmUpdates() async {
    for await alarms in AlarmManager.shared.alarmUpdates {
      if Task.isCancelled { break }
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
