import MapKit
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @State private var trainMapStore = TrainMapStore()

  @State private var showAddSheet = false
  @State private var showFeedbackBoard = false
  @State private var selectedTrains: [ProjectedTrain] = []

  var body: some View {
    Group {
      ZStack(alignment: .topTrailing) {
        TrainMapView(selectedTrains: selectedTrains)

        MapStylePicker(selectedStyle: $trainMapStore.selectedMapStyle)
          .padding(.trailing)
      }
      .sheet(isPresented: .constant(true)) {
        // Bottom card
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text("Perjalanan Kereta")
              .font(.title2).bold()
            Spacer()
            Menu {
              Button("Feedback Board", systemImage: "bubble.left.and.bubble.right") {
                showFeedbackBoard = true
              }
              Button("Pengaturan", systemImage: "gearshape") {}
            } label: {
              Circle().fill(.thinMaterial)
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: "ellipsis").foregroundStyle(.black))
            }
          }

          // Show trains if available, otherwise show add button
          if selectedTrains.isEmpty {
            Button {
              showAddSheet = true
            } label: {
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray.opacity(0.15))
                .frame(maxWidth: .infinity)
                .overlay(
                  VStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 42, weight: .semibold))
                    Text("Tambah Perjalanan Kereta")
                      .font(.headline)
                      .foregroundStyle(.secondary)
                  }
                )
            }
            .buttonStyle(.plain)
          } else {
            VStack(spacing: 12) {
              ForEach(selectedTrains) { train in
                TrainCard(
                  train: train,
                  onDelete: {
                    deleteTrain(train)
                  })
              }
            }
          }
        }
        .presentationBackgroundInteraction(.enabled)
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .padding(.horizontal, 21)
        .padding(.top, 23)
        .sheet(isPresented: $showAddSheet) {
          AddTrainView(
            onTrainSelected: { train in
              selectedTrains.append(train)
              trainMapStore.selectTrain(train: train)
              showAddSheet = false
            }
          )
          .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFeedbackBoard) {
          FeedbackBoardScreen()
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.ultraThinMaterial)
        }
      }
    }.environment(trainMapStore)
  }

  private func deleteTrain(_ train: ProjectedTrain) {
    withAnimation(.spring(response: 0.3)) {
      selectedTrains.removeAll { $0.id == train.id }
    }
  }
}

#Preview {
  HomeScreen()
}
