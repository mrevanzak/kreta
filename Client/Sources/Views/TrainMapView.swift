import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore
  @Environment(\.showToast) private var showToast

  @State private var cameraPosition: MapCameraPosition = .automatic

  var body: some View {
    Map(position: $cameraPosition) {
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
    .onChange(of: mapStore.liveTrainPosition) { _, newPosition in
      if let position = newPosition {
        updateCameraPosition(with: [position])
      }
    }
    .onAppear {
      // Ensure data loads on app launch even if subscription hasn't fired yet
      if let lastUpdatedAt = mapStore.lastUpdatedAt {
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
  }

  // MARK: - Computed Properties

  /// Filter routes based on selected train - builds complete journey routes from segments
  private var filteredRoutes: [Route] {
    guard let journeyData = mapStore.selectedJourneyData else {
      return mapStore.routes
    }

    // Collect all unique route IDs from journey segments
    var routeIds = Set<String>()
    for segment in journeyData.segments {
      if let routeId = segment.routeId {
        routeIds.insert(routeId)
      }
    }

    return mapStore.routes.filter { routeIds.contains($0.id) }
  }

  /// Filter stations based on selected train - shows all stations along journey path
  private var filteredStations: [Station] {
    guard let journeyData = mapStore.selectedJourneyData else {
      return mapStore.stations
    }

    // Get all unique stations from complete journey path
    var stationCodes = Set<String>()
    for station in journeyData.allStations {
      stationCodes.insert(station.code)
    }

    return mapStore.stations.filter { stationCodes.contains($0.code) }
  }

  /// Filter trains based on selected train - shows live projected position if available
  private var filteredTrains: [ProjectedTrain] {
    guard let selectedTrain = mapStore.selectedTrain else {
      return []
    }

    // Return live projected position if available, otherwise return original train
    return [mapStore.liveTrainPosition ?? selectedTrain]
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

  // MARK: - Camera Management

  private func updateCameraPosition(with positions: [ProjectedTrain]) {
    guard !positions.isEmpty else { return }

    // If single train, follow it with smooth animation
    if positions.count == 1, let train = positions.first {
      withAnimation(.easeInOut(duration: 1.0)) {
        cameraPosition = .region(
          MKCoordinateRegion(
            center: train.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
          )
        )
      }
    } else {
      // Multiple trains - show all in view
      let coordinates = positions.map { $0.coordinate }
      updateCameraToFitCoordinates(coordinates)
    }
  }

  private func updateCameraToFitCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
    guard !coordinates.isEmpty else { return }

    var minLat = coordinates[0].latitude
    var maxLat = coordinates[0].latitude
    var minLon = coordinates[0].longitude
    var maxLon = coordinates[0].longitude

    for coord in coordinates {
      minLat = min(minLat, coord.latitude)
      maxLat = max(maxLat, coord.latitude)
      minLon = min(minLon, coord.longitude)
      maxLon = max(maxLon, coord.longitude)
    }

    let center = CLLocationCoordinate2D(
      latitude: (minLat + maxLat) / 2,
      longitude: (minLon + maxLon) / 2
    )

    let span = MKCoordinateSpan(
      latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
      longitudeDelta: max((maxLon - minLon) * 1.5, 0.05)
    )

    withAnimation(.easeInOut(duration: 1.0)) {
      cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
  }
}
