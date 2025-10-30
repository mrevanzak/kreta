import SwiftUI

enum FeedbackSortOption: String, CaseIterable {
  case votes
  case date
}

enum FeedbackSortOrder: String, CaseIterable {
  case ascending
  case descending
}

struct FeedbackBoardView: View {
  @Environment(\.dismiss) var dismiss
  @State private var store = FeedbackStore()
  @State private var showSubmissionSheet = false
  @State private var sortOption: FeedbackSortOption = .votes
  @State private var sortOrder: FeedbackSortOrder = .descending

  var sortedItems: [FeedbackItem] {
    var items = store.feedbackItems
    switch sortOption {
    case .votes:
      items.sort { a, b in
        sortOrder == .ascending ? (a.voteCount < b.voteCount) : (a.voteCount > b.voteCount)
      }
    case .date:
      items.sort { a, b in
        sortOrder == .ascending ? (a.createdAt < b.createdAt) : (a.createdAt > b.createdAt)
      }
    }
    return items
  }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottomTrailing) {
        Color.black.ignoresSafeArea()

        VStack(spacing: 16) {
          headerView

          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(sortedItems) { item in
                FeedbackCard(item: item, store: store)
                  .padding(.horizontal)
              }
            }
            .padding(.vertical)
          }
        }

        Button(action: { showSubmissionSheet = true }) {
          Image(systemName: "plus")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Circle().fill(.thinMaterial))
            .background(Circle().fill(Color.blue.opacity(0.9)))
        }
        .padding(24)
        .shadow(radius: 8)
      }
    }
    .sheet(isPresented: $showSubmissionSheet) {
      FeedbackSubmissionSheet(store: store)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
  }

  private var headerView: some View {
    HStack {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .foregroundStyle(.white)
          .padding(10)
          .background(Circle().fill(.thinMaterial))
      }

      Spacer()

      Text("Feedback Board")
        .font(.headline)
        .foregroundStyle(.white)

      Spacer()

      Menu {
        Picker("Sort by", selection: $sortOption) {
          ForEach(FeedbackSortOption.allCases, id: \.self) { option in
            Text(option.rawValue.capitalized).tag(option)
          }
        }
        Picker("Order", selection: $sortOrder) {
          ForEach(FeedbackSortOrder.allCases, id: \.self) { order in
            Text(order.rawValue.capitalized).tag(order)
          }
        }
      } label: {
        Image(systemName: "arrow.up.arrow.down")
          .foregroundStyle(.black)
          .frame(width: 38, height: 38)
          .background(Circle().fill(.thinMaterial))
      }
    }
    .padding(.horizontal)
    .padding(.top)
  }
}


