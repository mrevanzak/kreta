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
    let sorted = feedbackStore.feedbackItems.sorted { (a: FeedbackItem, b: FeedbackItem) -> Bool in
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
    Group {
      NavigationStack {
        List(sortedItems) {
          FeedbackCard(item: $0, hasVoted: feedbackStore.hasUserVoted(feedbackId: $0.id))
            .listRowSeparator(.hidden, edges: .all)
            .listRowBackground(Color.clear)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .listStyle(.plain)
        .listRowSpacing(2)
        .animation(.smooth(duration: 0.35), value: sortedItems.map(\.id))
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(role: .close) {
              dismiss()
            } label: {
              Image(systemName: "xmark")
            }
          }
          ToolbarItem(placement: .navigationBarLeading) {
            sortMenu
          }
        }
        .overlay {
          if sortedItems.isEmpty {
            ContentUnavailableView(
              "Belum ada masukkan",
              systemImage: "bubble.left.and.bubble.right",
              description: Text("Ayo tulis ide/masukkan kamu disini!")
            )
          }
        }
        .overlay(alignment: .bottomTrailing) {
          Button {
            showSubmissionSheet = true
          } label: {
            Image(systemName: "plus")
              .font(.title2)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .frame(width: 56, height: 56)
              .background(Color.highlight, in: Circle())
              .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 14, y: 6)
          }
          .padding(.trailing, 28)
        }
      }
      .sheet(isPresented: $showSubmissionSheet) {
        FeedbackSubmissionSheet()
          .presentationDetents([.large])
          .presentationDragIndicator(.hidden)
      }
    }
    .environment(feedbackStore)
    .presentationBackground(.ultraThickMaterial)
  }

  private var sortMenu: some View {
    Menu {
      Section("Sort by") {
        ForEach(SortOption.allCases, id: \.self) { option in
          Button {
            withAnimation(.smooth(duration: 0.35)) {
              sortOption = option
            }
          } label: {
            Label(option.displayName, systemImage: sortOption == option ? "checkmark" : "")
          }
        }
      }

      Section("Order") {
        ForEach(SortOrder.allCases, id: \.self) { order in
          Button {
            withAnimation(.smooth(duration: 0.35)) {
              sortOrder = order
            }
          } label: {
            Label(order.displayName, systemImage: sortOrder == order ? "checkmark" : "")
          }
        }
      }
    } label: {
      Image(systemName: "arrow.up.arrow.down")
    }
  }

  private var primaryContentColor: Color {
    colorScheme == .dark ? .white : .black.opacity(0.9)
  }

  private var secondaryContentColor: Color {
    colorScheme == .dark ? .white.opacity(0.65) : .black.opacity(0.55)
  }

}

#Preview {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      view(for: .feedback)
    }
}
