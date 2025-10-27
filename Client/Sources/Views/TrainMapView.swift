import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore
  @Environment(\.showToast) private var showToast

  var body: some View {
    Group {
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
      .mapStyle(
        .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: false)
      )
      .ignoresSafeArea()
    }
    .task {
      do {
        try await mapStore.loadInitial()
      } catch let error as TrainMapError {
        let errorMessage = "\(error.errorName): \(error.localizedDescription)"
        print("🚂 TrainMapView: \(errorMessage)")
        showToast(errorMessage)
      } catch {
        let errorMessage = "UnknownError: \(error.localizedDescription)"
        print("🚂 TrainMapView: \(errorMessage)")
        showToast(errorMessage)
      }
    }
  }
}

#Preview {
  TrainMapView()
    .environment(TrainMapStore.preview)
}
