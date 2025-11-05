import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore
  @Environment(\.showToast) private var showToast

  @Binding var isFollowing: Bool
  @Binding var focusTrigger: Bool
  @State private var cameraPosition: MapCameraPosition = .automatic

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Map(position: $cameraPosition) {
        // Routes
        ForEach(filteredRoutes) { route in
          let coords = route.coordinates
          if coords.count > 1 {
            MapPolyline(coordinates: coords)
              .stroke(.blue, lineWidth: 3)
          }
        }
        // Stations (simple marker for visibility)
        ForEach(filteredStations) { station in
          Marker(station.name, systemImage: "tram.fill", coordinate: station.coordinate)
            .tint(.green)
        }
        // Live train(s)
        ForEach(filteredTrains) { train in
          let isMoving = train.moving
          Marker("\(train.name) (\(train.code))", systemImage: "tram.fill", coordinate: train.coordinate)
            .tint(isMoving ? .blue : .red)
        }
      }
      // break follow as soon as user interacts with the map
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { _ in
          if isFollowing { isFollowing = false }
        }
      )
    }
    .mapControlVisibility(.hidden)
    .mapStyle(mapStyleForCurrentSelection)
    .ignoresSafeArea()

    // Data refresh on timestamp tick
    .onChange(of: mapStore.lastUpdatedAt) { _, lastUpdatedAt in
      guard let lastUpdatedAt else { return }
      Task(priority: .high) {
        do {
          try await mapStore.loadData(at: lastUpdatedAt)
        } catch let error as TrainMapError {
          let msg = "\(error.errorName): \(error.localizedDescription)"
          print("🚂 TrainMapView: \(msg)")
          showToast(msg)
        }
      }
    }

    // Follow live position updates
    .onChange(of: mapStore.liveTrainPosition) { _, newPosition in
      if let position = newPosition {
        updateCameraPosition(with: [position])
      }
    }

    // External “focus” poke from the sheet button
    .onChange(of: focusTrigger) { _, newValue in
      if newValue {
        isFollowing = true
        if let position = mapStore.liveTrainPosition {
          updateCameraPosition(with: [position])
        }
      }
    }

    // Initial load
    .onAppear {
      if let lastUpdatedAt = mapStore.lastUpdatedAt {
        Task(priority: .high) {
          do {
            try await mapStore.loadData(at: lastUpdatedAt)
          } catch let error as TrainMapError {
            let msg = "\(error.errorName): \(error.localizedDescription)"
            print("🚂 TrainMapView: \(msg)")
            showToast(msg)
          }
        }
      }
    }

    // Auto-reset the trigger after it’s consumed so it’s fire-once
    .task(id: focusTrigger) {
      if focusTrigger {
        focusTrigger = false
      }
    }
  }

  // MARK: - Computed filters

  private var filteredRoutes: [Route] {
    guard let journeyData = mapStore.selectedJourneyData else {
      return mapStore.routes
    }
    var routeIds = Set<String>()
    for segment in journeyData.segments {
      if let routeId = segment.routeId {
        routeIds.insert(routeId)
      }
    }
    return mapStore.routes.filter { routeIds.contains($0.id) }
  }

    private var filteredStations: [Station] {
      guard let jd = mapStore.selectedJourneyData else {
        return mapStore.stations
      }

      // Get stop station IDs derived from segment times only
      let stopIds = Set(jd.stopStationIds(dwellThreshold: 30)) // tweak threshold if needed

      // Match against Station.id first, then fallback to code
      return mapStore.stations.filter { st in
        let key = st.id ?? st.code
        return stopIds.contains(key)
      }
    }


  private var filteredTrains: [ProjectedTrain] {
    guard let selectedTrain = mapStore.selectedTrain else { return [] }
    return [mapStore.liveTrainPosition ?? selectedTrain]
  }

  // MARK: - Map style

  private var mapStyleForCurrentSelection: MapStyle {
    switch mapStore.selectedMapStyle {
    case .standard:
      return .standard(elevation: .realistic, emphasis: .automatic, pointsOfInterest: .all, showsTraffic: false)
    case .hybrid:
      return .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: false)
    }
  }

  // MARK: - Camera

  private func updateCameraPosition(with positions: [ProjectedTrain]) {
    guard !positions.isEmpty else { return }
    guard isFollowing else { return } // respect user exploration

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
      let coords = positions.map { $0.coordinate }
      updateCameraToFitCoordinates(coords)
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
