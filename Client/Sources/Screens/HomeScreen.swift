import MapKit
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @State private var trainMapStore = TrainMapStore()

  @State private var showAddSheet = false
  @State private var showFeedbackBoard = false

  var body: some View {
    Group {
      ZStack(alignment: .topTrailing) {
        TrainMapView()

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

          // Show train if available, otherwise show add button
          if let train = trainMapStore.selectedTrain {
            // Use live projected train if available, otherwise use original
            let displayTrain = trainMapStore.liveTrainPosition ?? train
            TrainCard(
              train: displayTrain,
              journeyData: trainMapStore.selectedJourneyData,
              onDelete: {
                deleteTrain()
              })
          } else {
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
            onTrainSelected: { train, journeyData in
              if let journeyData = journeyData {
                Task {
                  do {
                    try await trainMapStore.selectTrain(train, journeyData: journeyData)
                    showAddSheet = false
                  } catch {
                    // Handle error - could show alert
                    print("Failed to select train: \(error)")
                  }
                }
              } else {
                showAddSheet = false
              }
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
    }
    .environment(trainMapStore)
    .onOpenURL { url in
      let components = url.fullComponents
      if components == ["trip", "start"],
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
      {
        let journeyId = items.first(where: { $0.name == "journeyId" })?.value
        let trainId = items.first(where: { $0.name == "trainId" })?.value

        if let trainId {
          Task {
            do {
              try await trainMapStore.startFromDeepLink(trainId: trainId, journeyId: journeyId)
            } catch {
              print("Failed to start from deeplink: \(error)")
            }
          }
        }
      }
    }
    .task {
      try? await trainMapStore.loadSelectedTrainFromCache()
    }
  }

  private func deleteTrain() {
    Task {
      await trainMapStore.clearSelectedTrain()
    }
  }
}

#Preview {
  HomeScreen()
}
