import Combine
import ConvexMobile
import Foundation
import Observation

@MainActor
@Observable
final class FeedbackStore {
  private let convexClient = Dependencies.shared.convexClient
  @ObservationIgnored private var cancellable: AnyCancellable?

  var feedbackItems: [FeedbackItem] = []
  var isLoading = false

  init() {
    cancellable = convexClient
      .subscribe(to: "feedback:list", yielding: [FeedbackItem].self)
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] items in
          self?.feedbackItems = items
        }
      )
  }

  func submitFeedback(title: String, description: String, email: String?) async throws {
    guard let deviceToken = PushRegistrationService.shared.currentToken()
      ?? UIDevice.current.identifierForVendor?.uuidString
    else { throw NSError(domain: "feedback", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing device token"]) }

    isLoading = true
    defer { isLoading = false }

    let request = CreateFeedbackRequest(
      title: title,
      description: description,
      email: (email?.isEmpty == true ? nil : email),
      deviceToken: deviceToken
    )

    _ = try await convexClient.mutation(
      "feedback:create",
      with: [
        "title": request.title,
        "description": request.description,
        "email": request.email,
        "deviceToken": request.deviceToken,
      ],
      yielding: CreateFeedbackResponse.self
    )
  }

  func toggleVote(feedbackId: String) async throws {
    guard let deviceToken = PushRegistrationService.shared.currentToken()
      ?? UIDevice.current.identifierForVendor?.uuidString
    else { return }

    let response: ToggleVoteResponse = try await convexClient.mutation(
      "feedback:toggleVote",
      with: [
        "feedbackId": feedbackId,
        "deviceToken": deviceToken,
      ],
      yielding: ToggleVoteResponse.self
    )

    UserDefaults.standard.set(
      response.voted,
      forKey: voteKey(deviceToken: deviceToken, feedbackId: feedbackId)
    )
  }

  func hasUserVoted(feedbackId: String) -> Bool {
    let deviceToken = PushRegistrationService.shared.currentToken()
      ?? UIDevice.current.identifierForVendor?.uuidString ?? ""
    return UserDefaults.standard.bool(forKey: voteKey(deviceToken: deviceToken, feedbackId: feedbackId))
  }

  private func voteKey(deviceToken: String, feedbackId: String) -> String {
    "voted_\(deviceToken)_\(feedbackId)"
  }
}


