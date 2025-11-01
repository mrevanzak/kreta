import MapKit
import SwiftUI

struct TrainMapView: View {
  @Environment(TrainMapStore.self) private var mapStore
  @Environment(\.showToast) private var showToast

  let selectedTrains: [ProjectedTrain]
  let journeyDataMap: [String: TrainJourneyData]
  @Binding var liveTrainPositions: [String: ProjectedTrain]
  
  @State private var projectionTimer: Timer?
  @State private var cameraPosition: MapCameraPosition = .automatic

  init(
    selectedTrains: [ProjectedTrain] = [],
    journeyDataMap: [String: TrainJourneyData] = [:],
    liveTrainPositions: Binding<[String: ProjectedTrain]>
  ) {
    self.selectedTrains = selectedTrains
    self.journeyDataMap = journeyDataMap
    self._liveTrainPositions = liveTrainPositions
  }

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
    .onChange(of: selectedTrains) { _, _ in
      startProjectingTrains()
    }
    .onChange(of: liveTrainPositions) { _, newPositions in
      updateCameraPosition(with: newPositions)
    }
    .onAppear {
      startProjectingTrains()
    }
    .onDisappear {
      stopProjectingTrains()
    }
  }

  // MARK: - Computed Properties

  /// Filter routes based on selected trains - builds complete journey routes from segments
  private var filteredRoutes: [Route] {
    guard !selectedTrains.isEmpty else {
      return mapStore.routes
    }

    // Collect all unique route IDs from journey segments
    var routeIds = Set<String>()
    for train in selectedTrains {
      if let journeyData = journeyDataMap[train.id] {
        for segment in journeyData.segments {
          if let routeId = segment.routeId {
            routeIds.insert(routeId)
          }
        }
      }
    }

    return mapStore.routes.filter { routeIds.contains($0.id) }
  }

  /// Filter stations based on selected trains - shows all stations along journey path
  private var filteredStations: [Station] {
    guard !selectedTrains.isEmpty else {
      return mapStore.stations
    }

    // Get all unique stations from complete journey paths
    var stationCodes = Set<String>()
    for train in selectedTrains {
      if let journeyData = journeyDataMap[train.id] {
        for station in journeyData.allStations {
          stationCodes.insert(station.code)
        }
      }
    }

    return mapStore.stations.filter { stationCodes.contains($0.code) }
  }

  /// Filter trains based on selected trains - shows live projected position if available
  private var filteredTrains: [ProjectedTrain] {
    guard !selectedTrains.isEmpty else {
      return []
    }

    // Return live projected positions for all selected trains
    return selectedTrains.compactMap { train in
      liveTrainPositions[train.id]
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
  
  // MARK: - Train Projection
  
  private func startProjectingTrains() {
    stopProjectingTrains()
    
    // Project immediately
    projectAllTrains()
    
    // Set up timer for continuous updates
    let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
      Task { @MainActor in
        self.projectAllTrains()
      }
    }
    projectionTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }
  
  private func stopProjectingTrains() {
    projectionTimer?.invalidate()
    projectionTimer = nil
  }
  
  private func projectAllTrains() {
    let stationsById = Dictionary(uniqueKeysWithValues: mapStore.stations.map { ($0.id ?? $0.code, $0) })
    let routesById = Dictionary(uniqueKeysWithValues: mapStore.routes.map { ($0.id, $0) })
    let now = Date()
    let nowMs = now.timeIntervalSince1970 * 1000
    
    var newPositions: [String: ProjectedTrain] = [:]
    
    for train in selectedTrains {
      // Get journey data for this train
      guard let journeyData = journeyDataMap[train.id] else {
        print("⚠️ No journey data for train \(train.id)")
        continue
      }
      
      // Convert to TrainJourney model
      let trainJourney = TrainJourney(
        id: train.id,
        trainId: train.id,
        code: train.code,
        name: train.name,
        segments: journeyData.segments
      )
      
      // Project the train position
      if let projected = TrainProjector.projectTrain(
        now: now,
        journey: trainJourney,
        stationsById: stationsById,
        routesById: routesById
      ) {
        newPositions[train.id] = projected
      } else {
        print("❌ Failed to project train \(train.code) - likely outside active time window")
      }
    }
    liveTrainPositions = newPositions
  }
  
  private func updateCameraPosition(with positions: [String: ProjectedTrain]) {
    guard !positions.isEmpty else { return }
    
    // If single train, follow it with smooth animation
    if positions.count == 1, let train = positions.values.first {
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
      let coordinates = positions.values.map { $0.coordinate }
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
