import MapKit
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @Environment(Router.self) private var router
  @State private var trainMapStore = TrainMapStore()

  @State private var isFollowing: Bool = true
  @State private var focusTrigger: Bool = false
  @State private var selectedDetent: PresentationDetent = .height(200)

  var body: some View {
    Group {
      TrainMapView(
        bottomInset: bottomInset
      )
      .sheet(isPresented: .constant(true)) {
        // Bottom card or full journey view
        Group {
          if selectedDetent == .large, let train = trainMapStore.selectedTrain {
            // Full journey progress view
            let displayTrain = trainMapStore.liveTrainPosition ?? train
            JourneyProgressView(
              train: displayTrain,
              journeyData: trainMapStore.selectedJourneyData,
              onDelete: {
                deleteTrain()
                selectedDetent = .height(200)
              }
            )
          } else {
            // Compact view with train card or add button
            compactBottomSheet
          }
        }
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationDetents(presentationDetents, selection: $selectedDetent)
        .presentationDragIndicator(selectedDetent == .large ? .visible : .hidden)
        .interactiveDismissDisabled(true)
        .animation(.easeInOut(duration: 0.3), value: trainMapStore.selectedTrain?.id)
        .animation(.easeInOut(duration: 0.3), value: selectedDetent)
        .onChange(of: trainMapStore.selectedTrain) { oldValue, newValue in
          // Reset to compact when train changes or is removed
          if newValue == nil {
            selectedDetent = .fraction(0.35)
          } else if oldValue?.id != newValue?.id {
            selectedDetent = .height(200)
          }
        }
        .routerPresentation(router: router)
      }
    }
    .environment(trainMapStore)
    .task {
      try? await trainMapStore.loadSelectedTrainFromCache()
    }
  }
  
  // MARK: - Computed Properties
  
  private var bottomInset: CGFloat {
    if selectedDetent == .large {
      return Screen.height * 0.9
    } else if trainMapStore.selectedTrain != nil {
      return 200
    } else {
      return Screen.height * 0.35
    }
  }
  
  private var detentHeight: CGFloat {
    trainMapStore.selectedTrain != nil ? 200 : Screen.height * 0.35
  }
  
  private var presentationDetents: Set<PresentationDetent> {
    if trainMapStore.selectedTrain != nil {
      return [.height(200), .large]
    } else {
      return [.fraction(0.35)]
    }
  }
  
  // MARK: - Subviews
  
  @ViewBuilder
  private var compactBottomSheet: some View {
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
  }
  
  // MARK: - Actions

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
