import ActivityKit
import ConvexMobile
import Foundation

final class TrainLiveActivityService: @unchecked Sendable {
  static let shared = TrainLiveActivityService()

  private let convexClient: ConvexClient
  private var hasStartedGlobalMonitoring = false

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
    }
    return activity
  }

  @MainActor
  func update(
    activityId: String,
    previousStation: TrainStation,
    nextStation: TrainStation,
  ) async {
    let contentState = TrainActivityAttributes.ContentState(
      previousStation: previousStation,
      nextStation: nextStation,
    )
    for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
      await activity.update(ActivityContent(state: contentState, staleDate: nil))
    }
  }

  @MainActor
  func end(
    activityId: String,
    dismissalPolicy: ActivityUIDismissalPolicy = .immediate
  ) async {
    for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
      await activity.end(nil, dismissalPolicy: dismissalPolicy)
    }
  }

  @MainActor
  func endAllImmediately() async {
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
