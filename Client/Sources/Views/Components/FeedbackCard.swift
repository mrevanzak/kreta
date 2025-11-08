//
//  FeedbackCard.swift
//  kreta
//
//  Liquid glass styled feedback card with vote button and status
//

import SwiftUI

struct FeedbackCard: View {
  @Environment(FeedbackStore.self) private var store
  @Environment(\.colorScheme) private var colorScheme

  @State private var hasVoted = false
  @State private var localVoteCount: Int
  @State private var isVoting = false

  let item: FeedbackItem

  init(item: FeedbackItem, hasVoted: Bool) {
    self.item = item
    _hasVoted = State(initialValue: hasVoted)
    _localVoteCount = State(initialValue: item.voteCount)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      // Left side: content
      VStack(alignment: .leading, spacing: 12) {
        // Title
        Text(item.description)
          .font(.headline)
          .foregroundStyle(primaryTextColor)

        statusTag

        // // Description
        // Text(item.description)
        //   .font(.subheadline)
        //   .foregroundStyle(secondaryTextColor)
        //   .lineLimit(3)

        // Timestamp
        Text(item.relativeTime)
          .font(.caption)
          .foregroundStyle(secondaryTextColor)
      }

      Spacer()

      // Right side: vote button
      VStack(spacing: 4) {
        voteButton

        Text("\(localVoteCount)")
          .font(.caption2)
          .foregroundStyle(secondaryTextColor)
      }
    }
    .padding(20)
    .background(cardGlassBackground)
    .clipShape(cardShape)
    .overlay(
      cardShape
        .stroke(cardBorderGradient, lineWidth: 1)
    )
    .shadow(color: cardShadowColor, radius: 24, x: 0, y: 12)
  }

  private var statusTag: some View {
    Text(item.status.rawValue.capitalized)
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
        .font(.title3.weight(.semibold))
        .foregroundStyle(hasVoted ? voteAccentColor : secondaryTextColor)
        .frame(width: 36, height: 40)
        .background(
          cardActionBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        let result = try await store.toggleVote(feedbackId: item.id)
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

  private var cardShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
  }

  private var primaryTextColor: Color {
    colorScheme == .dark ? .white : .black.opacity(0.9)
  }

  private var secondaryTextColor: Color {
    colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.55)
  }

  private var cardGlassBackground: some View {
    cardShape
      .fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.95 : 0.98))
      .background(
        cardShape
          .fill(cardGlassTint)
          .blur(radius: 36)
      )
  }

  private var cardGlassTint: LinearGradient {
    LinearGradient(
      colors: colorScheme == .dark
        ? [
          Color.white.opacity(0.18),
          Color.white.opacity(0.04),
        ]
        : [
          Color.white.opacity(0.8),
          Color.white.opacity(0.45),
        ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var cardBorderGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color.white.opacity(colorScheme == .dark ? 0.35 : 0.6),
        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.25),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var cardShadowColor: Color {
    colorScheme == .dark ? .black.opacity(0.45) : .black.opacity(0.12)
  }

  private var cardActionBackground: LinearGradient {
    LinearGradient(
      colors: [
        Color.blue.opacity(colorScheme == .dark ? 0.35 : 0.4),
        Color.cyan.opacity(colorScheme == .dark ? 0.45 : 0.5),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var voteAccentColor: Color {
    colorScheme == .dark ? .cyan : .blue
  }
}

// Helper extension for hex colors
extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a: UInt64
    let r: UInt64
    let g: UInt64
    let b: UInt64
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
    id: "1",
    // title: "Add dark mode support",
    description:
      "It would be great to have a dark mode option for users who prefer darker interfaces.",
    status: .pending,
    createdAt: Float(Date().timeIntervalSince1970 - 3600),
    voteCount: 42
  )

  ZStack {
    Color.black.ignoresSafeArea()
    FeedbackCard(item: item, hasVoted: false)
      .padding()
      .environment(store)
  }
}
