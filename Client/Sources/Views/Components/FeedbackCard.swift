//
//  FeedbackCard.swift
//  kreta
//
//  Liquid glass styled feedback card with vote button and status
//

import SwiftUI

struct FeedbackCard: View {
  let item: FeedbackItem
  let store: FeedbackStore

  @State private var hasVoted = false
  @State private var localVoteCount: Int
  @State private var isVoting = false

  init(item: FeedbackItem, store: FeedbackStore) {
    self.item = item
    self.store = store
    _hasVoted = State(initialValue: store.hasUserVoted(feedbackId: item._id))
    _localVoteCount = State(initialValue: item.voteCount)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      // Left side: content
      VStack(alignment: .leading, spacing: 12) {
        // Title and status
        HStack(spacing: 8) {
          Text(item.title)
            .font(.headline)
            .foregroundStyle(.white)

          statusTag

          Spacer()
        }

        // Description
        Text(item.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(3)

        // Timestamp
        Text(item.relativeTime)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // Right side: vote button
      VStack(spacing: 4) {
        voteButton

        Text("\(localVoteCount)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
    )
  }

  private var statusTag: some View {
    Text(item.status.capitalized)
      .font(.caption2)
      .fontWeight(.semibold)
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color(hex: item.statusColor), in: RoundedRectangle(cornerRadius: 8))
  }

  private var voteButton: some View {
    Button {
      handleVoteToggle()
    } label: {
      Image(systemName: hasVoted ? "triangle.fill" : "triangle")
        .font(.title3)
        .foregroundStyle(hasVoted ? .cyan : .secondary)
        .frame(width: 32, height: 32)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    .disabled(isVoting)
  }

  private func handleVoteToggle() {
    guard !isVoting else { return }

    // Optimistic update
    isVoting = true
    let previousHasVoted = hasVoted
    let previousVoteCount = localVoteCount

    if hasVoted {
      hasVoted = false
      localVoteCount = max(0, localVoteCount - 1)
    } else {
      hasVoted = true
      localVoteCount += 1
    }

    // Actual vote
    Task {
      do {
        let result = try await store.toggleVote(feedbackId: item._id)
        // Only update if result differs (shouldn't happen but safety net)
        hasVoted = result
        if result != previousHasVoted {
          localVoteCount = result ? previousVoteCount + 1 : previousVoteCount - 1
        }
      } catch {
        // Revert optimistic update
        hasVoted = previousHasVoted
        localVoteCount = previousVoteCount
        print("❌ Vote toggle error: \(error)")
      }
      isVoting = false
    }
  }
}

// Helper extension for hex colors
extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 6:  // RGB
      (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    case 8:  // ARGB
      (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

#Preview {
  let store = FeedbackStore()
  let item = FeedbackItem(
    _id: "1",
    title: "Add dark mode support",
    description: "It would be great to have a dark mode option for users who prefer darker interfaces.",
    email: "user@example.com",
    status: "pending",
    createdAt: Int(Date().timeIntervalSince1970 - 3600) * 1000,
    voteCount: 42
  )

  ZStack {
    Color.black.ignoresSafeArea()
    FeedbackCard(item: item, store: store)
      .padding()
  }
}

