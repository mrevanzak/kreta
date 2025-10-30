//
//  FeedbackBoardView.swift
//  kreta
//
//  Main feedback board view with sorting and FAB for new submissions
//

import SwiftUI

struct FeedbackBoardView: View {
  @Environment(\.dismiss) var dismiss
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
      ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 0) {
          headerView

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
        }

        // FAB
        VStack {
          Spacer()
          HStack {
            Spacer()

            Button {
              showSubmissionSheet = true
            } label: {
              Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.blue, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
          }
        }
      }
    }
    .sheet(isPresented: $showSubmissionSheet) {
      FeedbackSubmissionSheet(store: feedbackStore)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
  }

  private var headerView: some View {
    VStack(spacing: 0) {
      HStack {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
        }

        Spacer()

        Text("Feedback & Roadmap")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(.white)

        Spacer()

        sortMenu
      }
      .padding(.horizontal, 21)
      .padding(.vertical, 16)

      Divider()
        .background(Color.white.opacity(0.1))
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
        .font(.title3)
        .foregroundStyle(.white)
        .frame(width: 32, height: 32)
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      Text("No feedback yet")
        .font(.title3)
        .foregroundStyle(.white)

      Text("Be the first to share your ideas!")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 64)
  }
}

#Preview {
  FeedbackBoardView()
}

