import ActivityKit
import ConvexMobile
import Foundation

final class TrainLiveActivityService: @unchecked Sendable {
  static let shared = TrainLiveActivityService()

  private let convexClient: ConvexClient
  private var hasStartedGlobalMonitoring = false
  private var transitionTimers: [String: Task<Void, Never>] = [:]

  private init(
    convexClient: ConvexClient = Dependencies.shared.convexClient
  ) {
    self.convexClient = convexClient
  }

  @discardableResult
  @MainActor
  func start(
    trainName: String,
    from: TrainStation,
    destination: TrainStation,
    nextStation: TrainStation,
    seatClass: SeatClass,
    seatNumber: String,
  ) async throws -> Activity<TrainActivityAttributes> {
    let attributes = TrainActivityAttributes(
      trainName: trainName,
      from: from,
      destination: destination,
      seatClass: seatClass,
      seatNumber: seatNumber,
    )
    let contentState = TrainActivityAttributes.ContentState(
      previousStation: from, nextStation: nextStation
    )
    let content = ActivityContent(state: contentState, staleDate: nil)
    let activity = try Activity<TrainActivityAttributes>.request(
      attributes: attributes,
      content: content
    )
    Task {
      await monitorPushTokens(for: activity)
      await startAutomaticTransitions(for: activity)
    }
    return activity
  }

  @MainActor
  func update(
    activityId: String,
    previousStation: TrainStation,
    nextStation: TrainStation,
    journeyState: JourneyState? = nil
  ) async {
    // Get current state to preserve journeyState if not provided
    var contentState = TrainActivityAttributes.ContentState(
      previousStation: previousStation,
      nextStation: nextStation
    )

    // If journeyState is provided, use it; otherwise preserve existing state
    if let newJourneyState = journeyState {
      contentState = TrainActivityAttributes.ContentState(
        previousStation: previousStation,
        nextStation: nextStation,
        journeyState: newJourneyState
      )
    } else {
      // Find the activity to preserve current journeyState
      for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
        contentState = TrainActivityAttributes.ContentState(
          previousStation: previousStation,
          nextStation: nextStation,
          journeyState: activity.content.state.journeyState
        )
        break
      }
    }

    for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
      await activity.update(ActivityContent(state: contentState, staleDate: nil))
    }
  }

  @MainActor
  func updateJourneyState(activityId: String, newState: JourneyState) async {
    for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
      let currentState = activity.content.state
      let contentState = TrainActivityAttributes.ContentState(
        previousStation: currentState.stations.previous,
        nextStation: currentState.stations.next,
        journeyState: newState
      )
      await activity.update(ActivityContent(state: contentState, staleDate: nil))
    }
  }

  @MainActor
  func transitionToOnBoard(activityId: String) async {
    await updateJourneyState(activityId: activityId, newState: .onBoard)
  }

  @MainActor
  func transitionToPrepareToDropOff(activityId: String) async {
    await updateJourneyState(activityId: activityId, newState: .prepareToDropOff)
  }

  @MainActor
  private func startAutomaticTransitions(for activity: Activity<TrainActivityAttributes>) async {
    let activityId = activity.id

    // Cancel any existing timer for this activity
    transitionTimers[activityId]?.cancel()

    // Create a new timer task
    let timerTask = Task<Void, Never> {
      defer { transitionTimers.removeValue(forKey: activityId) }

      // Transition to .onBoard when departure time arrives
      if let departureTime = activity.attributes.from.estimatedDeparture {
        let delay = max(0, departureTime.timeIntervalSinceNow)
        if delay > 0 {
          try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
          await transitionToOnBoard(activityId: activityId)
        }
      }

      // Transition to .arrived when arrival time arrives
      if let arrivalTime = activity.attributes.destination.estimatedArrival {
        let delay = max(0, arrivalTime.timeIntervalSinceNow)
        if delay > 0 {
          try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
          await transitionToPrepareToDropOff(activityId: activityId)
        }
      }
    }

    transitionTimers[activityId] = timerTask
  }

  @MainActor
  func end(
    activityId: String,
    dismissalPolicy: ActivityUIDismissalPolicy = .immediate
  ) async {
    // Cancel any running timers for this activity
    transitionTimers[activityId]?.cancel()
    transitionTimers.removeValue(forKey: activityId)

    for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
      await activity.end(nil, dismissalPolicy: dismissalPolicy)
    }
  }

  @MainActor
  func endAllImmediately() async {
    // Cancel all running timers
    for timer in transitionTimers.values {
      timer.cancel()
    }
    transitionTimers.removeAll()

    for activity in Activity<TrainActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private func monitorPushTokens(for activity: Activity<TrainActivityAttributes>) async {
    for await tokenData in activity.pushTokenUpdates {
      let token = tokenData.hexEncodedString()
      await registerLiveActivityToken(activityId: activity.id, token: token)
    }

    Task {
      await monitorPushToStartTokens()
    }
  }

  @MainActor
  func startGlobalMonitoring() async {
    guard !hasStartedGlobalMonitoring else { return }
    hasStartedGlobalMonitoring = true

    Task {
      await monitorExistingActivities()
    }

    Task {
      await monitorActivityUpdates()
    }

    Task {
      await monitorPushToStartTokens()
    }
  }

  private func monitorExistingActivities() async {
    for activity in Activity<TrainActivityAttributes>.activities {
      await monitorPushTokens(for: activity)
    }
  }

  private func monitorActivityUpdates() async {
    for await activity in Activity<TrainActivityAttributes>.activityUpdates {
      await monitorPushTokens(for: activity)
    }
  }

  private func registerLiveActivityToken(activityId: String, token: String) async {
    var attempt = 0
    let maxAttempts = 3

    while attempt < maxAttempts {
      do {
        // deviceToken required by server registrations.registerLiveActivityToken
        guard let deviceToken = PushRegistrationService.shared.currentToken() else { return }
        let _: RegisterLiveActivityTokenResponse = try await convexClient.mutation(
          "registrations:registerLiveActivityToken",
          with: [
            "activityId": activityId,
            "token": token,
            "deviceToken": deviceToken,
          ],
          captureTelemetry: true)
        return
      } catch {
        attempt += 1
        if attempt >= maxAttempts {
          return
        }
        let delay = UInt64(pow(2.0, Double(attempt)) * 0.5 * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
      }
    }
  }

  private func monitorPushToStartTokens() async {
    for await tokenData in Activity<TrainActivityAttributes>.pushToStartTokenUpdates {
      let token = tokenData.hexEncodedString()
      await registerLiveActivityStartToken(token: token)
    }
  }

  private func registerLiveActivityStartToken(token: String) async {
    var attempt = 0
    let maxAttempts = 3

    while attempt < maxAttempts {
      do {
        // deviceToken required by server registrations.registerLiveActivityStartToken
        guard let deviceToken = PushRegistrationService.shared.currentToken() else { return }
        let _: RegisterLiveActivityTokenResponse = try await convexClient.mutation(
          "registrations:registerLiveActivityStartToken",
          with: [
            "deviceToken": deviceToken,
            "token": token,
            "userId": nil,
          ],
          captureTelemetry: true)
        return
      } catch {
        attempt += 1
        if attempt >= maxAttempts {
          return
        }
        let delay = UInt64(pow(2.0, Double(attempt)) * 0.5 * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
      }
    }
  }
}
