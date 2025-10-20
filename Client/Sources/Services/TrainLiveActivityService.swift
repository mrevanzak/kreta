import ActivityKit
import Foundation

@MainActor
final class TrainLiveActivityService {
  static let shared = TrainLiveActivityService()

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
}
