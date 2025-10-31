import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore
  @Environment(\.showToast) private var showToast
  
  let selectedTrains: [ProjectedTrain]
  
  init(selectedTrains: [ProjectedTrain] = []) {
    self.selectedTrains = selectedTrains
  }

  var body: some View {
    Map {
      // Lines (polylines) - show only selected train routes or all routes
      ForEach(filteredRoutes) { route in
        let coords = route.coordinates
        if coords.count > 1 {
          MapPolyline(coordinates: coords)
            .stroke(.blue, lineWidth: 3)
        }
      }
      // Stations (annotations) - show only connected stations or all stations
      ForEach(filteredStations) { station in
        Annotation(station.name, coordinate: station.coordinate) {
          ZStack {
            Circle().fill(.white).frame(width: 10, height: 10)
            Circle().stroke(.blue, lineWidth: 2).frame(width: 14, height: 14)
          }
        }
      }
      // Train positions (symbols) - show only selected trains or all trains
      ForEach(filteredTrains) { train in
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
  
  // MARK: - Computed Properties
  
  /// Filter routes based on selected trains
  private var filteredRoutes: [Route] {
    guard !selectedTrains.isEmpty else {
      return mapStore.routes
    }
    
    let selectedRouteIds = Set(selectedTrains.compactMap { $0.routeIdentifier })
    return mapStore.routes.filter { selectedRouteIds.contains($0.id) }
  }
  
  /// Filter stations based on selected trains
  private var filteredStations: [Station] {
    guard !selectedTrains.isEmpty else {
      return mapStore.stations
    }
    
    // Get all unique stations from selected trains
    var stationCodes = Set<String>()
    for train in selectedTrains {
      if let fromStation = train.fromStation {
        stationCodes.insert(fromStation.code)
      }
      if let toStation = train.toStation {
        stationCodes.insert(toStation.code)
      }
    }
    
    return mapStore.stations.filter { stationCodes.contains($0.code) }
  }
  
  /// Filter trains based on selected trains
  private var filteredTrains: [ProjectedTrain] {
    guard !selectedTrains.isEmpty else {
      return mapStore.trains
    }
    
    let selectedTrainIds = Set(selectedTrains.map { $0.id })
    return mapStore.trains.filter { train in
      selectedTrainIds.contains(train.id)
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
