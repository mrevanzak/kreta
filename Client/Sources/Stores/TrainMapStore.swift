import Combine
import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private let service: TrainMapService
  private let convexClient = Dependencies.shared.convexClient
  private let cacheService = TrainMapCacheService()

  var isLoading: Bool = false
  var selectedMapStyle: MapStyleOption = .hybrid
  var selectedTrain: ProjectedTrain? {
    didSet {
      if let selectedTrain {
        projectTrains()
      }
    }
  }

  var stations: [Station] = [] {
    didSet { projectTrains() }
  }
  var routes: [Route] = [] {
    didSet { projectTrains() }
  }
  var trains: [ProjectedTrain] = []
  private var rawTrains: [RawGapekaTrain] = [] {
    didSet { projectTrains() }
  }

  var lastUpdatedAt: String?

  @ObservationIgnored private var projectionTimer: Timer?
  @ObservationIgnored private var lastUpdatedAtCancellable: AnyCancellable?

  let logger = Logger(subsystem: "kreta", category: String(describing: TrainMapStore.self))

  init(service: TrainMapService) {
    self.service = service

    lastUpdatedAtCancellable = convexClient.subscribe(
      to: "gapeka:getLastUpdatedAt", yielding: String.self
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
        && cacheService.hasCachedTrains()

      let needsUpdate = cachedTimestamp != timestamp || !hasCompleteCache

      if needsUpdate {
        logger.debug("Cache stale or missing. Fetching fresh data...")

        // Start all fetches concurrently
        async let stationsResult = fetchStationsFromConvex()
        async let routesResult = service.fetchRoutes()
        async let trainsResult = service.fetchTrainPositions()

        // Await and update each result as it completes
        do {
          let stations = try await stationsResult
          logger.debug("Fetched \(stations.count) stations")
          self.stations = stations
          try cacheService.saveStations(stations)
        } catch {
          logger.error("Stations fetch error: \(error)")
          throw TrainMapError.stationsSubscriptionFailed(error.localizedDescription)
        }

        do {
          let routes = try await routesResult
          logger.debug("Fetched \(routes.count) routes")
          self.routes = routes
          try cacheService.saveRoutes(routes)
        } catch {
          logger.error("Routes fetch error: \(error)")
          throw TrainMapError.routesFetchFailed(error.localizedDescription)
        }

        do {
          let trains = try await trainsResult
          logger.debug("Fetched \(trains.count) trains")
          self.rawTrains = trains
          try cacheService.saveTrains(trains)
        } catch {
          logger.error("Train positions fetch error: \(error)")
          throw TrainMapError.trainPositionsFetchFailed(error.localizedDescription)
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
    routes = try cacheService.loadCachedRoutes()
    rawTrains = try cacheService.loadCachedTrains()
  }

  fileprivate func loadCachedDataIfAvailable() throws -> Bool {
    guard cacheService.hasCachedStations(), cacheService.hasCachedRoutes(),
      cacheService.hasCachedTrains()
    else { return false }

    try loadCachedData()
    return true
  }

  fileprivate func fetchStationsFromConvex() async throws -> [Station] {
    try await withCheckedThrowingContinuation { continuation in
      var didResume = false
      var cancellable: AnyCancellable?

      cancellable = convexClient.subscribe(to: "stations:get", yielding: [Station].self)
        .receive(on: DispatchQueue.main)
        .sink(
          receiveCompletion: { completion in
            if case let .failure(error) = completion, !didResume {
              didResume = true
              continuation.resume(
                throwing: TrainMapError.stationsSubscriptionFailed(error.localizedDescription))
            }
          },
          receiveValue: { stations in
            guard !didResume else { return }
            cancellable?.cancel()
            didResume = true
            continuation.resume(returning: stations)
          })
    }
  }
}

// MARK: - Projection management
extension TrainMapStore {
  func projectTrains(now: Date = Date()) {
    guard !rawTrains.isEmpty else {
      trains = []
      return
    }

    let stationLookup = Dictionary(uniqueKeysWithValues: stations.map { ($0.code, $0) })
    let routeLookupByIdentifier = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })

    let projected = rawTrains.compactMap { train in
      TrainProjector.projectTrain(
        now: now,
        train: train,
        stationsByCode: stationLookup,
        routesByIdentifier: routeLookupByIdentifier,
      )
    }

    trains = projected
  }

  func startProjectionUpdates(interval: TimeInterval = 1.0) {
    stopProjectionUpdates()
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      guard let self else { return }
      self.projectTrains()
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
  func selectTrain(train: ProjectedTrain) {
    selectedTrain = train
  }

  func removeSelectedTrain() {
    selectedTrain = nil
  }
}

// MARK: - Mapping helpers
extension TrainMapStore {
  static var preview: TrainMapStore {
    let store = TrainMapStore(service: TrainMapService(httpClient: .development))
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
    store.trains = [
      ProjectedTrain(
        id: "T1-0",
        code: "T1",
        name: "Sample Express",
        position: Position(latitude: -6.1950, longitude: 106.8500),
        moving: true,
        bearing: 45,
        routeIdentifier: "L1",
        speedKph: 60,
        fromStation: store.stations.first,
        toStation: store.stations.last,
        segmentDeparture: Date().addingTimeInterval(-15 * 60),
        segmentArrival: Date().addingTimeInterval(15 * 60),
        progress: 0.5,
        journeyDeparture: Date().addingTimeInterval(-60 * 60),
        journeyArrival: Date().addingTimeInterval(2 * 60 * 60)
      )
    ]
    return store
  }
}
