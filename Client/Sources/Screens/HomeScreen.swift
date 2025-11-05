import MapKit
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @Environment(Router.self) private var router
  @State private var trainMapStore = TrainMapStore()

  @State private var isFollowing: Bool = true
  @State private var focusTrigger: Bool = false

  var body: some View {
    Group {
      TrainMapView(
        bottomInset: trainMapStore.selectedTrain != nil ? CGFloat(200) : Screen.height * 0.35
      )
      .sheet(isPresented: .constant(true)) {
        // Bottom card
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("Perjalanan Kereta")
              .font(.title2).bold()
            Spacer()
            Menu {
              Button("Feedback Board", systemImage: "bubble.left.and.bubble.right") {
                router.navigate(to: .sheet(.feedback))
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
              router.navigate(to: .sheet(.addTrain))
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
        .routerPresentation(router: router)
      }
    }
    .environment(trainMapStore)
    .task {
      try? await trainMapStore.loadSelectedTrainFromCache()
    }
  }

  private func deleteTrain() {
    Task { @MainActor in
      await trainMapStore.clearSelectedTrain()
    }
  }

  @ViewBuilder
  func navigationView(for destination: SheetDestination, from router: Router)
    -> some View
  {
    NavigationContainer(parentRouter: router) { view(for: destination) }
  }

  @ViewBuilder
  func navigationView(for destination: FullScreenDestination, from router: Router)
    -> some View
  {
    NavigationContainer(parentRouter: router) { view(for: destination) }
  }
}
