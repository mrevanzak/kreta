import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore
  @Environment(\.showToast) private var showToast

  var body: some View {
    Map {
      // Lines (polylines)
      ForEach(mapStore.routes) { route in
        let coords = route.coordinates
        if coords.count > 1 {
          MapPolyline(coordinates: coords)
            .stroke(.blue, lineWidth: 3)
        }
      }
      // Stations (annotations)
      ForEach(mapStore.stations) { station in
        Annotation(station.name, coordinate: station.coordinate) {
          ZStack {
            Circle().fill(.white).frame(width: 10, height: 10)
            Circle().stroke(.blue, lineWidth: 2).frame(width: 14, height: 14)
          }
        }
      }
      // Train positions (symbols)
      ForEach(mapStore.trains) { train in
        let isMoving = train.moving
        Marker(
          "\(train.name) (\(train.id))", systemImage: "tram.fill", coordinate: train.coordinate
        )
        .tint(isMoving ? .green : .blue)
      }
    }
    .mapControlVisibility(.hidden)
    .mapStyle(mapStyleForCurrentSelection)
    .ignoresSafeArea()
    .onChange(of: mapStore.lastUpdatedAt) { _, lastUpdatedAt in
      guard let lastUpdatedAt else { return }

      Task(priority: .high) {
        do {
          try await mapStore.loadData(at: lastUpdatedAt)
        } catch let error as TrainMapError {
          let errorMessage = "\(error.errorName): \(error.localizedDescription)"
          print("🚂 TrainMapView: \(errorMessage)")
          showToast(errorMessage)
        }
      }
    }
  }

  // MARK: - Map Style Computation
  private var mapStyleForCurrentSelection: MapStyle {
    switch mapStore.selectedMapStyle {
    case .standard:
      return .standard(
        elevation: .realistic, emphasis: .automatic, pointsOfInterest: .all, showsTraffic: false)
    case .hybrid:
      return .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: false)
    }
  }
}
