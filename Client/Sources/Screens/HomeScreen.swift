import MapKit
import Portal
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @Environment(Router.self) private var router
  @Environment(\.colorScheme) private var colorScheme
  @State private var trainMapStore = TrainMapStore()

  @State private var isFollowing: Bool = true
  @State private var focusTrigger: Bool = false
  @State private var selectedDetent: PresentationDetent = .height(200)
  @State private var showInstaView: Bool = false  // Added state for InstaView

  private var isPortalActive: Binding<Bool> {
    Binding(
      get: { selectedDetent == .large },
      set: { active in
        selectedDetent = active ? .large : .height(200)
      }
    )
  }

  var gradient: LinearGradient {
    let colors: [Color]

    if colorScheme == .dark {
      // Dark mode gradient
      colors = [
        .black.opacity(0.5),
        .white,
        .black.opacity(0.5),
      ]
    } else {
      // Light mode gradient
      colors = [
        .clear,
        .white,
        .clear,
      ]
    }

    return LinearGradient(
      colors: colors,
      startPoint: UnitPoint(x: 0.0, y: 0.0),
      endPoint: UnitPoint(x: 1.0, y: 1.0)
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
              } else if selectedDetent == .height(80), let train = trainMapStore.selectedTrain {
                // Minimal view with train name and destination
                minimalTrainView(train: trainMapStore.liveTrainPosition ?? train)
              } else {
                // Compact view with train card or add button
                compactBottomSheet
              }
            }
            .presentationBackgroundInteraction(.enabled)
            .presentationDetents(presentationDetents, selection: $selectedDetent)
            .presentationDragIndicator(trainMapStore.selectedTrain == nil ? .hidden : .visible)
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
          // InstaView Sheet
          .sheet(isPresented: $showInstaView) {
            InstaView()
              .environment(trainMapStore)
          }
      }
      .environment(trainMapStore)
      .portalTransition(
        id: "trainName",
        isActive: isPortalActive,  // <- use the computed Binding
        animation: .spring(response: 0.2, dampingFraction: 0.8),
        completionCriteria: .removed
      ) {
        if let train = trainMapStore.liveTrainPosition ?? trainMapStore.selectedTrain {
          if isPortalActive.wrappedValue {
            Text(train.name)
              .font(.title3.weight(.bold))
              .fixedSize(horizontal: true, vertical: false)
          }
        }
      }
      .portalTransition(
        id: "trainCode",
        isActive: isPortalActive,  // <- use the computed Binding
      ) {
        if isPortalActive.wrappedValue,
          let train = trainMapStore.liveTrainPosition ?? trainMapStore.selectedTrain
        {
          Text("(\(train.code))")
            .fontWeight(.bold)
            .foregroundStyle(.sublime)
        }
      }
    }
    .task {
      try? await trainMapStore.loadSelectedTrainFromCache()
    }
  }

  // MARK: - Computed Properties

  private var presentationDetents: Set<PresentationDetent> {
    if trainMapStore.selectedTrain != nil {
      return [.height(80), .height(200), .large]
    } else {
      return [.fraction(0.35)]
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private func minimalTrainView(train: ProjectedTrain) -> some View {
    let destinationStation =
      trainMapStore.selectedJourneyData?.userSelectedToStation.code
      ?? train.toStation?.code
      ?? "Tujuan"

    VStack(alignment: .leading, spacing: 4) {
      Text("\(train.name) Menuju \(destinationStation)")
        .font(.title2.weight(.bold))
        .foregroundStyle(.primary)

      Text(formatRemainingTime(train: train))
        .font(.subheadline)
        .foregroundStyle(Color(hex: "818181"))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .padding(.horizontal)
  }

  @ViewBuilder
  private var compactBottomSheet: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Perjalanan Kereta")
          .font(.title2).bold()
        Spacer()

        if trainMapStore.selectedTrain != nil {
          Button {
            router.navigate(to: .sheet(.shareJourney))
          } label: {
            ZStack {
              Circle()
                .strokeBorder(.gray.opacity(0.2), lineWidth: 1)
                .frame(width: 44, height: 44)

              Circle()
                .strokeBorder(self.gradient, lineWidth: 1)
                .opacity(1 * 1.2)
                .frame(width: 44, height: 44)

              Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.textSecondary)
            }
            .frame(width: 44, height: 44)  // Larger tap area
            .contentShape(Circle())  // Make entire area tappable
          }
          .padding(.trailing, 4)
        }

        Menu {
          if trainMapStore.selectedTrain != nil, trainMapStore.selectedJourneyData != nil {
            Button("Atur Alarm Kedatangan", systemImage: "bell.badge") {
              router.navigate(to: .sheet(.alarmConfiguration))
            }
          }

          Button("Feedback Board", systemImage: "bubble.left.and.bubble.right") {
            router.navigate(to: .sheet(.feedback))
          }

          #if DEBUG
            Button("Alarm Debug", systemImage: "list.bullet") {
              router.navigate(to: .sheet(.alarmDebug))
            }
          #endif
        } label: {
          ZStack {
            Circle()
              .strokeBorder(.gray.opacity(0.2), lineWidth: 1)
              .frame(width: 44, height: 44)

            Circle()
              .strokeBorder(self.gradient, lineWidth: 1)
              .opacity(1 * 1.2)
              .frame(width: 44, height: 44)

            Image(systemName: "ellipsis")
              .foregroundStyle(.textSecondary)
          }
          .frame(width: 44, height: 44)  // Larger tap area
          .contentShape(Circle())  // Make entire area tappable
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

  private func formatRemainingTime(train: ProjectedTrain) -> String {
    // Use journey data if available for user-selected times
    let departure =
      trainMapStore.selectedJourneyData?.userSelectedDepartureTime ?? train.journeyDeparture
    let arrival = trainMapStore.selectedJourneyData?.userSelectedArrivalTime ?? train.journeyArrival

    guard let departure = departure, let arrival = arrival else {
      return "Waktu tidak tersedia"
    }

    let now = Date()

    // Check if train hasn't departed yet
    if now < departure {
      return "Kereta belum berangkat"
    }

    // Check if train has already arrived
    if now >= arrival {
      return "Sudah Tiba"
    }

    // Calculate time remaining until arrival (mirrors TrainCard logic)
    let timeInterval = arrival.timeIntervalSince(now)
    let totalMinutes = Int(timeInterval / 60)

    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    // Return only the time string without "Tiba Dalam"
    if hours > 0 && minutes > 0 {
      return "\(hours) Jam \(minutes) Menit"
    } else if hours > 0 {
      return "\(hours) Jam"
    } else if minutes > 0 {
      return "\(minutes) Menit"
    } else {
      return "Tiba Sebentar Lagi"
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
