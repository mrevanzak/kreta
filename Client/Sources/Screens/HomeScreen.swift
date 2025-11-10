import MapKit
import SwiftUI
import Portal

// MARK: - Main Map Screen

struct HomeScreen: View {
  @Environment(Router.self) private var router
  @State private var trainMapStore = TrainMapStore()
  
  @State private var isFollowing: Bool = true
  @State private var focusTrigger: Bool = false
  @State private var selectedDetent: PresentationDetent = .height(200)
  private var isPortalActive: Binding<Bool> {
    Binding(
      get: { selectedDetent == .large },
      set: { active in
        selectedDetent = active ? .large : .height(200)
      }
    )
  }
  
  var body: some View {
    PortalContainer {
      Group {
        TrainMapView()
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
            .presentationBackgroundInteraction(.enabled)
            .presentationDetents(presentationDetents, selection: $selectedDetent)
            .presentationDragIndicator(selectedDetent == .fraction(0.35) ? .hidden : .visible)
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
      .portalTransition(
        id: "trainName",
        isActive: isPortalActive, // <- use the computed Binding
        animation: .spring(response: 0.2, dampingFraction: 0.8),
        completionCriteria: .removed
      ) {
        if let train = trainMapStore.liveTrainPosition ?? trainMapStore.selectedTrain {
          if isPortalActive.wrappedValue {
            Text(train.name)
              .font(.title3.weight(.bold))
              .frame(width: 250)
          }
        }
      }
      .task {
        try? await trainMapStore.loadSelectedTrainFromCache()
      }
    }
  }
  
  // MARK: - Computed Properties
  
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
        
        if let train = trainMapStore.selectedTrain {
          Button {
            
          } label: {
            Circle().fill(.thinMaterial)
              .frame(width: 38, height: 38)
              .overlay(Image(systemName: "square.and.arrow.up").foregroundStyle(.black))
          }
        }
        
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
