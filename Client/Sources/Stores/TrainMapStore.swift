import Combine
import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private let convexClient = Dependencies.shared.convexClient
  private let cacheService = TrainMapCacheService()

  var isLoading: Bool = false
  var selectedMapStyle: MapStyleOption = .hybrid
  var selectedTrain: ProjectedTrain? {
    didSet {
      Task { await persistSelectedTrain() }
    }
  }

  var stations: [Station] = []
  var routes: [Route] = []
  var lastUpdatedAt: String?

  var selectedJourneyData: TrainJourneyData? {
    didSet {
      Task { await persistJourneyData() }
    }
  }

  // Timestamp for triggering live position updates (must be observable)
  private var projectionTimestamp: Date = Date()

  var liveTrainPosition: ProjectedTrain? {
    guard selectedTrain != nil, selectedJourneyData != nil else { return nil }
    // Access projectionTimestamp to establish dependency for observation
    _ = projectionTimestamp
    return projectSelectedTrain(now: Date())
  }

  @ObservationIgnored private var projectionTimer: Timer?
  @ObservationIgnored private var lastUpdatedAtCancellable: AnyCancellable?

  let logger = Logger(subsystem: "kreta", category: String(describing: TrainMapStore.self))

  init() {

    // Load cached data immediately on init for instant display
    if (try? loadCachedDataIfAvailable()) != nil {
      logger.debug("Loaded cached data on initialization")
    }

    lastUpdatedAtCancellable = convexClient.subscribe(
      to: "gapeka:getLastUpdatedAt", yielding: String.self, captureTelemetry: true
    )
    .receive(on: DispatchQueue.main)
    .sink(
      receiveCompletion: { completion in
        switch completion {
        case .finished:
          self.logger.debug("LastUpdatedAt subscription completed")
        case .failure(let error):
          self.logger.error("LastUpdatedAt subscription error: \(error)")
        }
      },
      receiveValue: { lastUpdatedAt in
        self.logger.debug("Received lastUpdatedAt: \(lastUpdatedAt)")
        self.lastUpdatedAt = lastUpdatedAt
      })
  }

  func loadData(at timestamp: String) async throws {
    logger.debug("Starting loadData(at: \(timestamp))")

    isLoading = true
    defer { isLoading = false }

    stopProjectionUpdates()

    do {
      let cachedTimestamp = cacheService.getCachedTimestamp()
      logger.debug("Fetched cached timestamp: \(String(describing: cachedTimestamp))")

      let hasCompleteCache =
        cacheService.hasCachedStations()
        && cacheService.hasCachedRoutes()

      let needsUpdate = cachedTimestamp != timestamp || !hasCompleteCache

      if needsUpdate {
        logger.debug("Cache stale or missing. Fetching fresh data in parallel...")

        async let routesResult: [RoutePolyline] = Task { @MainActor in
          try await convexClient.query(to: "routes:list", yielding: [RoutePolyline].self)
        }.value
        async let stationsResult: [Station] = Task { @MainActor in
          try await convexClient.query(to: "station:list", yielding: [Station].self)
        }.value

        do {
          let routePolylines = try await routesResult
          logger.debug("Fetched \(routePolylines.count) routes")
          self.routes = routePolylines.map { Route(id: $0.id, name: $0.name, path: $0.path) }
          try cacheService.saveRoutes(routePolylines)
        } catch {
          logger.error("Routes fetch error: \(error)")
          throw TrainMapError.routesFetchFailed(error.localizedDescription)
        }

        do {
          let stations = try await stationsResult
          logger.debug("Fetched \(stations.count) stations")
          self.stations = stations
          try cacheService.saveStations(stations)
        } catch {
          logger.error("Stations fetch error: \(error)")
          throw TrainMapError.stationsFetchFailed(error.localizedDescription)
        }

      } else {
        logger.debug("Loading train map data from cache")
        try loadCachedData()
      }

      startProjectionUpdates()
      try cacheService.saveTimestamp(timestamp)

    } catch let error as TrainMapError {
      logger.error("TrainMapError encountered: \(error)")
      throw error
    } catch {
      logger.error("Unexpected error: \(error)")
      throw TrainMapError.dataMappingFailed(error.localizedDescription)
    }
  }
}

// MARK: - Data loading helpers
extension TrainMapStore {
  fileprivate func loadCachedData() throws {
    stations = try cacheService.loadCachedStations()
    let routePolylines = try cacheService.loadCachedRoutes()
    routes = routePolylines.map { Route(id: $0.id, name: $0.name, path: $0.path) }
  }

  fileprivate func loadCachedDataIfAvailable() throws -> Bool {
    guard cacheService.hasCachedStations(), cacheService.hasCachedRoutes()
    else { return false }

    try loadCachedData()
    return true
  }
}

// MARK: - Projection management
extension TrainMapStore {
  func startProjectionUpdates(interval: TimeInterval = 1.0) {
    stopProjectionUpdates()
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        // Update timestamp to trigger liveTrainPosition recalculation
        self.projectionTimestamp = Date()
      }
    }
    projectionTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func stopProjectionUpdates() {
    projectionTimer?.invalidate()
    projectionTimer = nil
  }
}

// MARK: - Selected train management
extension TrainMapStore {
  func selectTrain(_ train: ProjectedTrain, journeyData: TrainJourneyData) {
    selectedTrain = train
    selectedJourneyData = journeyData
    startProjectionUpdates()
  }

  func clearSelectedTrain() {
    selectedTrain = nil
    selectedJourneyData = nil
  }

  func loadSelectedTrainFromCache() async throws {
    selectedTrain = try cacheService.loadSelectedTrain()
    selectedJourneyData = try cacheService.loadJourneyData()
  }

  private func persistSelectedTrain() async {
    do {
      try cacheService.saveSelectedTrain(selectedTrain)
    } catch {
      logger.error("Failed to save selected train: \(error)")
    }
  }

  private func persistJourneyData() async {
    do {
      try cacheService.saveJourneyData(selectedJourneyData)
    } catch {
      logger.error("Failed to save journey data: \(error)")
    }
  }

  private func projectSelectedTrain(now: Date = Date()) -> ProjectedTrain? {
    guard let selectedTrain, let selectedJourneyData else { return nil }

    let stationsById = Dictionary(
      uniqueKeysWithValues: stations.map { ($0.id ?? $0.code, $0) })
    let routesById = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })

    let trainJourney = TrainJourney(
      id: selectedTrain.id,
      trainId: selectedTrain.id,
      code: selectedTrain.code,
      name: selectedTrain.name,
      segments: selectedJourneyData.segments
    )

    return TrainProjector.projectTrain(
      now: now,
      journey: trainJourney,
      stationsById: stationsById,
      routesById: routesById
    )
  }
}

// MARK: - Mapping helpers
extension TrainMapStore {
  static var preview: TrainMapStore {
    let store = TrainMapStore()
    store.stations = [
      Station(
        id: "GMR",
        code: "GMR",
        name: "Gambir",
        position: Position(latitude: -6.1774, longitude: 106.8306),
        city: nil
      ),
      Station(
        id: "JNG",
        code: "JNG",
        name: "Jatinegara",
        position: Position(latitude: -6.2149, longitude: 106.8707),
        city: nil
      ),
    ]
    store.routes = [
      Route(
        id: "L1",
        name: "Central Line",
        path: [
          Position(latitude: -6.1774, longitude: 106.8306),
          Position(latitude: -6.1900, longitude: 106.8450),
          Position(latitude: -6.2050, longitude: 106.8600),
          Position(latitude: -6.2149, longitude: 106.8707),
        ],
      )
    ]
    return store
  }
}
