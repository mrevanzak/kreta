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
  private nonisolated(unsafe) let convexClient = Dependencies.shared.convexClient
  private var cancellable: AnyCancellable?

  var feedbackItems: [FeedbackItem] = []
  var isLoading = false

  var deviceToken: String {
    // Prefer APNS token when available, otherwise use persistent device UUID
    PushRegistrationService.shared.currentToken() ?? persistentDeviceIdentifier()
  }

  /// Generates or retrieves a persistent device identifier from keychain
  /// This ensures each device has a unique identity even before APNS registration completes
  private func persistentDeviceIdentifier() -> String {
    let keychainKey = "deviceIdentifier"

    // Try to retrieve existing identifier
    if let existingId = Keychain<String>.get(keychainKey) {
      return existingId
    }

    // Generate new UUID and store in keychain
    let newIdentifier = UUID().uuidString
    Keychain.set(newIdentifier, forKey: keychainKey)
    return newIdentifier
  }

  init() {
    // Subscribe to feedback:list with real-time updates
    cancellable = convexClient.subscribe(
      to: "feedback:list", yielding: [FeedbackItem].self, captureTelemetry: true
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
      ],
      captureTelemetry: true)
  }

  func toggleVote(feedbackId: String) async throws -> Bool {
    let response: ToggleVoteResponse = try await convexClient.mutation(
      "feedback:toggleVote",
      with: [
        "feedbackId": feedbackId,
        "deviceToken": deviceToken,
      ],
      captureTelemetry: true)

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
