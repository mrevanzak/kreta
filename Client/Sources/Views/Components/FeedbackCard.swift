import SwiftUI

struct FeedbackCard: View {
  let item: FeedbackItem
  @Bindable var store: FeedbackStore

  @State private var hasVoted: Bool = false
  @State private var localVoteCount: Int = 0

  init(item: FeedbackItem, store: FeedbackStore) {
    self.item = item
    self._store = Bindable(wrappedValue: store)
    self._hasVoted = State(initialValue: store.hasUserVoted(feedbackId: item.id))
    self._localVoteCount = State(initialValue: item.voteCount)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text(item.title)
            .font(.headline)
            .foregroundStyle(.white)

          statusTag
        }

        Text(item.description)
          .foregroundStyle(.secondary)
          .font(.subheadline)

        Text(relativeTime(from: item.createdAt))
          .foregroundStyle(.secondary)
          .font(.caption)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(spacing: 6) {
        Button(action: handleVoteToggle) {
          Image(systemName: hasVoted ? "triangle.fill" : "triangle")
            .font(.title3)
            .foregroundStyle(hasVoted ? .cyan : .white.opacity(0.9))
        }

        Text("\(localVoteCount)")
          .font(.footnote)
          .foregroundStyle(.white)
      }
      .padding(.horizontal, 8)
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
    )
  }

  private var statusTag: some View {
    Text(item.status.capitalized)
      .font(.caption2)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        Capsule().fill(colorForStatus(item.statusColor).opacity(0.2))
      )
      .overlay(
        Capsule().stroke(colorForStatus(item.statusColor).opacity(0.6), lineWidth: 1)
      )
  }

  private func colorForStatus(_ name: String) -> Color {
    switch name {
    case "orange": return .orange
    case "green": return .green
    case "blue": return .blue
    default: return .gray
    }
  }

  private func relativeTime(from ms: Int) -> String {
    let seconds = TimeInterval(ms) / 1000.0
    let date = Date(timeIntervalSince1970: seconds)
    return date.formatted(.relative(presentation: .named))
  }

  private func handleVoteToggle() {
    let newVoted = !hasVoted
    hasVoted = newVoted
    localVoteCount += newVoted ? 1 : -1

    Task {
      do {
        try await store.toggleVote(feedbackId: item.id)
      } catch {
        // revert optimistic update on failure
        hasVoted.toggle()
        localVoteCount += hasVoted ? 1 : -1
      }
    }
  }
}


