import MapKit
import SwiftUI

// MARK: - Main Map Screen

struct HomeScreen: View {
  @State private var trainMapStore = TrainMapStore(
    service: TrainMapService(httpClient: .development))

  @State private var showAddSheet = false
  @State private var showBottomSheet = true

  var body: some View {
    TrainMapView()
      .environment(trainMapStore)
      .sheet(isPresented: $showBottomSheet) {
        // Bottom card
        VStack {
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

            Button {
              showAddSheet = true
            } label: {
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 180)
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
        .presentationDetents([.fraction(0.4)])
        .presentationBackground(.white)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .padding(.horizontal, 21)
        .sheet(isPresented: $showAddSheet) {
          // TrainPickerView()
        }
      }
  }
}

#Preview {
  HomeScreen()
}
