import MapKit
import SwiftUI

// MARK: - Models (lightweight placeholders)

struct Station: Identifiable, Hashable {
  let id = UUID()
  let code: String
  let name: String
  let city: String
}

struct TrainService: Identifiable, Hashable {
  let id = UUID()
  let name: String
  let departStation: Station
  let arriveStation: Station
  let departTime: String
  let arriveTime: String
}

// MARK: - Sample Data

let sampleStations: [Station] = [
  .init(code: "BD",  name: "Bandung Hall",      city: "Bandung"),
  .init(code: "KAC", name: "Kiaracondong",      city: "Bandung"),
  .init(code: "CIR", name: "Ciroyom",           city: "Bandung"),
  .init(code: "CMD", name: "Cimindi",           city: "Bandung"),
  .init(code: "SGU", name: "Surabaya Gubeng",   city: "Surabaya"),
  .init(code: "SBI", name: "Surabaya Pasar Turi", city: "Surabaya"),
  .init(code: "WO",  name: "Wonokromo",         city: "Surabaya")
]

func sampleTrains(from: Station, to: Station, on date: Date) -> [TrainService] {
  [
    .init(name: "Argo Wilis",       departStation: from, arriveStation: to, departTime: "08:30", arriveTime: "17:15"),
    .init(name: "Mutiara Selatan",  departStation: from, arriveStation: to, departTime: "08:30", arriveTime: "17:15"),
    .init(name: "Turangga",         departStation: from, arriveStation: to, departTime: "08:30", arriveTime: "17:15")
  ]
}

// MARK: - Main Map Screen

struct MainMapView: View {
  @State private var showAddSheet = false
  @State private var showBottomSheet = true
  @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -7.2575, longitude: 112.7521), span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 6.0)) // centered on Java
  
  var body: some View {
    NavigationStack {
      ZStack {
        Map(coordinateRegion: $region)
          .ignoresSafeArea()
        
        // Floating map style button (top-right)
        VStack {
          HStack {
            Spacer()
            Circle()
              .fill(.white)
              .frame(width: 40, height: 40)
              .overlay(Image(systemName: "map.fill").font(.title3))
              .padding(.trailing, 16)
          }
          Spacer()
        }
      }
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
        .presentationDetents([.height(264)])
        .padding(.horizontal, 21)
        .presentationBackground(.white)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showAddSheet) {
          TrainPickerView()
        }
      }
    }
  }
}

#Preview {
  MainMapView()
}
