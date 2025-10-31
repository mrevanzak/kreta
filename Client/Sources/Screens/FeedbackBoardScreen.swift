//
//  FeedbackBoardView.swift
//  kreta
//
//  Main feedback board view with sorting and FAB for new submissions
//

import SwiftUI

struct FeedbackBoardScreen: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @State private var feedbackStore = FeedbackStore()
  @State private var showSubmissionSheet = false
  @State private var sortOption: SortOption = .votes
  @State private var sortOrder: SortOrder = .descending

  var sortedItems: [FeedbackItem] {
    let sorted = feedbackStore.feedbackItems.sorted { a, b in
      let comparison: Bool
      switch sortOption {
      case .votes:
        comparison = a.voteCount < b.voteCount
      case .date:
        comparison = a.createdAt < b.createdAt
      }
      return sortOrder == .ascending ? comparison : !comparison
    }
    return sorted
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 16) {
          if sortedItems.isEmpty {
            emptyStateView
          } else {
            ForEach(sortedItems) { item in
              FeedbackCard(item: item, store: feedbackStore)
            }
          }
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
        }
        ToolbarItem(placement: .primaryAction) {
          sortMenu
        }
      }.overlay(alignment: .bottomTrailing) {
        Button {
          showSubmissionSheet = true
        } label: {
          Image(systemName: "plus")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Color.blue, in: Circle())
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 14, y: 6)
        }
        .padding(.trailing, 28)
      }
    }
    .sheet(isPresented: $showSubmissionSheet) {
      FeedbackSubmissionSheet(store: feedbackStore)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
  }

  private var sortMenu: some View {
    Menu {
      Section("Sort by") {
        ForEach(SortOption.allCases, id: \.self) { option in
          Button {
            sortOption = option
          } label: {
            Label(option.displayName, systemImage: sortOption == option ? "checkmark" : "")
          }
        }
      }

      Section("Order") {
        ForEach(SortOrder.allCases, id: \.self) { order in
          Button {
            sortOrder = order
          } label: {
            Label(order.displayName, systemImage: sortOrder == order ? "checkmark" : "")
          }
        }
      }
    } label: {
      Image(systemName: "arrow.up.arrow.down")
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 64))
        .foregroundStyle(secondaryContentColor)

      Text("No feedback yet")
        .font(.title3)
        .foregroundStyle(primaryContentColor)

      Text("Be the first to share your ideas!")
        .font(.subheadline)
        .foregroundStyle(secondaryContentColor)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 64)
  }

  private var primaryContentColor: Color {
    colorScheme == .dark ? .white : .black.opacity(0.9)
  }

  private var secondaryContentColor: Color {
    colorScheme == .dark ? .white.opacity(0.65) : .black.opacity(0.55)
  }

}

#Preview {
  FeedbackBoardScreen()
}
