#if canImport(ActivityKit) && os(iOS)
  import ActivityKit
  import Foundation

  @available(iOS 16.1, *)
  @MainActor
  final class TrainLiveActivityService {
    static let shared = TrainLiveActivityService()

    private init() {}

    @discardableResult
    func start(
      from: String,
      destination: String,
      nextStation: String,
      estimatedArrival: Date
    ) async throws -> Activity<TrainActivityAttributes> {
      let attributes = TrainActivityAttributes(from: from, destination: destination)
      let content = TrainActivityAttributes.ContentState(
        nextStation: nextStation,
        estimatedArrival: estimatedArrival
      )
      let activity = try Activity<TrainActivityAttributes>.request(
        attributes: attributes,
        contentState: content
      )
      return activity
    }

    func update(
      activityId: String,
      nextStation: String,
      estimatedArrival: Date
    ) async {
      let content = TrainActivityAttributes.ContentState(
        nextStation: nextStation,
        estimatedArrival: estimatedArrival
      )
      for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
        await activity.update(using: content)
      }
    }

    func end(
      activityId: String,
      finalNextStation: String? = nil,
      finalEstimatedArrival: Date? = nil,
      dismissalPolicy: ActivityUIDismissalPolicy = .immediate
    ) async {
      let content = TrainActivityAttributes.ContentState(
        nextStation: finalNextStation ?? "Arrived",
        estimatedArrival: finalEstimatedArrival ?? Date()
      )
      for activity in Activity<TrainActivityAttributes>.activities where activity.id == activityId {
        await activity.end(using: content, dismissalPolicy: dismissalPolicy)
      }
    }

    func endAllImmediately() async {
      for activity in Activity<TrainActivityAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
  }
#endif
