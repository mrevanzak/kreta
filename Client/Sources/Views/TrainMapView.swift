import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore

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
          Annotation("train_\(train.id)", coordinate: train.coordinate) {
            Image(systemName: "tram.fill")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.red)
              .rotationEffect(.degrees(train.bearing ?? 0))
          }
        }
      }
      .mapStyle(
        .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: false)
      )
      .ignoresSafeArea()
    }
    .task {
      await mapStore.loadInitial()
    }
    .onChange(of: mapStore.trains) { _, _ in
      print("trains changed: \(mapStore.trains)")
    }
  }

}

#Preview {
  TrainMapView()
    .environment(TrainMapStore.preview)
}
