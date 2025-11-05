import MapKit
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @State private var trainMapStore = TrainMapStore()

  @State private var showAddSheet = false
  @State private var showFeedbackBoard = false

    @State private var isFollowing: Bool = true
    @State private var focusTrigger: Bool = false

    var body: some View {
      Group {
        ZStack(alignment: .topTrailing) {
          TrainMapView(
            isFollowing: $isFollowing,
            focusTrigger: $focusTrigger
          )

          VStack(alignment: .trailing, spacing: 8) {
            MapStylePicker(selectedStyle: $trainMapStore.selectedMapStyle)
            if !isFollowing && trainMapStore.liveTrainPosition != nil {
              Button {
                focusTrigger = true
              } label: {
                Label("Focus", systemImage: "scope")
                  .font(.headline)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 10)
                  .background(.ultraThickMaterial, in: Capsule())
              }
            }
          }
          .padding(.trailing)
        }
      .sheet(isPresented: .constant(true)) {
        // Bottom card
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("Perjalanan Kereta")
              .font(.title2).bold()
            Spacer()
            Menu {
              Button("Feedback Board", systemImage: "bubble.left.and.bubble.right") {
                showFeedbackBoard = true
              }
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
              }
            )
            .transition(
              .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
              ))
          } else {
            Button {
              showAddSheet = true
            } label: {
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.backgroundSecondary)
                .frame(maxWidth: .infinity)
                .overlay(
                  VStack {
                    Image(systemName: "plus").font(.system(size: 56, weight: .bold))
                    Text("Tambah Perjalanan Kereta")
                      .font(.subheadline)
                      .foregroundStyle(.textSecondary)
                    Text("Mulai track perjalanan kereta di sini")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                )
            }
            .buttonStyle(.plain)
            .transition(
              .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
              ))
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPrimary)
        .presentationBackgroundInteraction(.enabled)
        .presentationDetents(
          trainMapStore.selectedTrain != nil ? [.height(200)] : [.fraction(0.35)]
        )
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .animation(.easeInOut(duration: 0.3), value: trainMapStore.selectedTrain?.id)
        .sheet(isPresented: $showAddSheet) {
          AddTrainView()
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
    Task { @MainActor in
      await trainMapStore.clearSelectedTrain()
    }
  }
}

#Preview {
  HomeScreen()
}
