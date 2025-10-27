import MapKit
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @State private var trainMapStore = TrainMapStore(
    service: TrainMapService(httpClient: .development))
  
  @State private var showAddSheet = false
  @State private var showBottomSheet = true
  @State private var selectedTrains: [ProjectedTrain] = []
  
  var body: some View {
    TrainMapView()
      .environment(trainMapStore)
      .sheet(isPresented: $showBottomSheet) {
        // Bottom card
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text("Perjalanan Kereta")
              .font(.title2).bold()
            Spacer()
            Menu {
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
                TrainCard(train: train, onDelete: {
                  deleteTrain(train)
                })
              }
            }
          }
        }
        .presentationBackgroundInteraction(.enabled)
        .presentationDetents([.fraction(0.35), .medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .padding(.horizontal, 21)
        .padding(.top, 23)
        .sheet(isPresented: $showAddSheet) {
          AddTrainView(
            store: trainMapStore,
            onTrainSelected: { train in
              selectedTrains.append(train)
              showAddSheet = false
            }
          )
          .presentationDragIndicator(.visible)
        }
      }
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
