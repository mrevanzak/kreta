//
//  FeedbackStore.swift
//  kreta
//
//  Observable store for feedback board with Convex real-time subscriptions
//

import Combine
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class FeedbackStore {
  private let convexClient = Dependencies.shared.convexClient
  private var cancellable: AnyCancellable?

  var feedbackItems: [FeedbackItem] = []
  var isLoading = false

  var deviceToken: String {
    UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
  }

  init() {
    // Subscribe to feedback:list with real-time updates
    cancellable = convexClient.subscribe(
      to: "feedback:list", yielding: [FeedbackItem].self
    )
    .receive(on: DispatchQueue.main)
    .sink(
      receiveCompletion: { completion in
        if case let .failure(error) = completion {
          print("❌ Feedback subscription error: \(error)")
        }
      },
      receiveValue: { [weak self] items in
        print("📝 Received \(items.count) feedback items")
        self?.feedbackItems = items
      }
    )
  }

  func submitFeedback(title: String, description: String, email: String?) async throws {
    isLoading = true
    defer { isLoading = false }

    let _: CreateFeedbackResponse = try await convexClient.mutation(
      "feedback:create",
      with: [
        "title": title,
        "description": description,
        "email": email,
        "deviceToken": deviceToken,
      ])
  }

  func toggleVote(feedbackId: String) async throws -> Bool {
    let response: ToggleVoteResponse = try await convexClient.mutation(
      "feedback:toggleVote",
      with: [
        "feedbackId": feedbackId,
        "deviceToken": deviceToken,
      ])

    // Store vote state in UserDefaults
    let key = "voted_\(deviceToken)_\(feedbackId)"
    UserDefaults.standard.set(response.voted, forKey: key)

    return response.voted
  }

  func hasUserVoted(feedbackId: String) -> Bool {
    let key = "voted_\(deviceToken)_\(feedbackId)"
    return UserDefaults.standard.bool(forKey: key)
  }
}

