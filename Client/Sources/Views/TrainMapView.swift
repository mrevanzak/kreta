import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore
  @Environment(\.showMessage) private var showMessage

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
          let isMoving = Date() >= train.segmentDeparture && Date() < train.segmentArrival
          Annotation(train.id, coordinate: train.coordinate) {
            VStack(spacing: 4) {
              Image(systemName: "tram.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isMoving ? .green : .blue)
                .rotationEffect(.degrees(train.bearing ?? 0))
              // Name + movement/ETA label
              HStack(spacing: 4) {
                Text(train.name)
                if isMoving {
                  Text("• moving")
                } else {
                  Text("• at station")
                }
              }
              .font(.caption2)
              .monospacedDigit()
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(.thinMaterial)
              .clipShape(Capsule())
            }
          }
        }
      }
      .mapStyle(
        .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: false)
      )
      .ignoresSafeArea()
      .animation(.linear(duration: 1.0), value: mapStore.trains)
    }
    .task {
      do {
        try await mapStore.loadInitial()
      } catch {
        showMessage(error.localizedDescription)
      }
    }
  }
}

#Preview {
  TrainMapView()
    .environment(TrainMapStore.preview)
}
