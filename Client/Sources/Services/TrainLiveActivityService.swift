import ActivityKit
import Foundation

@MainActor
final class TrainLiveActivityService {
  static let shared = TrainLiveActivityService()

  private let httpClient = HTTPClient()

  private init() {}

  @discardableResult
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

  func end(
    activityId: String,
    dismissalPolicy: ActivityUIDismissalPolicy = .immediate
  ) async {
    for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
      await activity.end(dismissalPolicy: dismissalPolicy)
    }
  }

  func endAllImmediately() async {
    for activity in Activity<TrainActivityAttributes>.activities {
      await activity.end(dismissalPolicy: .immediate)
    }
  }

  private func monitorPushTokens(for activity: Activity<TrainActivityAttributes>) async {
    for await tokenData in activity.pushTokenUpdates {
      let token = tokenData.hexEncodedString()
      await registerLiveActivityToken(activityId: activity.id, token: token)
    }
  }

  private func registerLiveActivityToken(activityId: String, token: String) async {
    let payload = RegisterLiveActivityTokenPayload(activityId: activityId, token: token)

    guard let data = try? JSONEncoder().encode(payload) else {
      return
    }

    let resource = Resource(
      url: Constants.Urls.registerLiveActivityToken,
      method: .post(data),
      modelType: RegisterLiveActivityTokenResponse.self
    )

    var attempt = 0
    let maxAttempts = 3

    while attempt < maxAttempts {
      do {
        _ = try await httpClient.load(resource)
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

private struct RegisterLiveActivityTokenPayload: Codable {
  let activityId: String
  let token: String
}
