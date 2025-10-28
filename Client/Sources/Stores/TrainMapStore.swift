import Combine
import Foundation
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private let service: TrainMapService
  private let convexClient = Dependencies.shared.convexClient
  private let cacheService = TrainMapCacheService()

  var isLoading: Bool = false
  var selectedMapStyle: MapStyleOption = .hybrid

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

  @ObservationIgnored private var stationsCancellable: AnyCancellable?
  @ObservationIgnored private var projectionTimer: Timer?

  init(service: TrainMapService) {
    self.service = service
  }

  func loadInitial() async throws {
    print("🚂 TrainMapStore: Starting loadInitial()")

    isLoading = true
    defer { isLoading = false }

    stopProjectionUpdates()

    do {
      let latestTimestamp = try await getLastUpdatedTimestamp()
      let cachedTimestamp = cacheService.getCachedTimestamp()

      let hasCompleteCache = cacheService.hasCachedStations()
        && cacheService.hasCachedRoutes()
        && cacheService.hasCachedTrains()

      let needsUpdate = cachedTimestamp != latestTimestamp || !hasCompleteCache

      if needsUpdate {
        print("🚂 TrainMapStore: Cache stale or missing. Fetching fresh data...")
        let stations = try await fetchStationsFromConvex()

        async let routesTask: [Route] = {
          do {
            let routes = try await service.fetchRoutes()
            print("🚂 TrainMapStore: Fetched \(routes.count) routes")
            return routes
          } catch {
            print("🚂 TrainMapStore: Routes fetch error: \(error)")
            throw TrainMapError.routesFetchFailed(error.localizedDescription)
          }
        }()

        async let trainsTask: [RawGapekaTrain] = {
          do {
            let raw = try await service.fetchTrainPositions()
            print("🚂 TrainMapStore: Fetched \(raw.count) trains")
            return raw
          } catch {
            print("🚂 TrainMapStore: Train positions fetch error: \(error)")
            throw TrainMapError.trainPositionsFetchFailed(error.localizedDescription)
          }
        }()

        let (routes, trains) = try await (routesTask, trainsTask)

        stationsCancellable?.cancel()
        self.stations = stations
        self.routes = routes
        self.rawTrains = trains

        try cacheService.saveStations(stations)
        try cacheService.saveRoutes(routes)
        try cacheService.saveTrains(trains)
        try cacheService.saveTimestamp(latestTimestamp)

      } else {
        print("🚂 TrainMapStore: Loading train map data from cache")
        try loadCachedData()
      }

      startProjectionUpdates()
      subscribeToStationsUpdates()

    } catch let error as TrainMapError {
      print("🚂 TrainMapStore: TrainMapError encountered: \(error)")
      if try loadCachedDataIfAvailable() {
        print("🚂 TrainMapStore: Loaded cached data due to error")
        startProjectionUpdates()
        subscribeToStationsUpdates()
      } else {
        throw error
      }
    } catch {
      print("🚂 TrainMapStore: Unexpected error: \(error)")
      if try loadCachedDataIfAvailable() {
        print("🚂 TrainMapStore: Loaded cached data after unexpected error")
        startProjectionUpdates()
        subscribeToStationsUpdates()
      } else {
        throw TrainMapError.dataMappingFailed(error.localizedDescription)
      }
    }
  }
}

// MARK: - Data loading helpers
private extension TrainMapStore {
  func loadCachedData() throws {
    stations = try cacheService.loadCachedStations()
    routes = try cacheService.loadCachedRoutes()
    rawTrains = try cacheService.loadCachedTrains()
  }

  func loadCachedDataIfAvailable() throws -> Bool {
    guard cacheService.hasCachedStations(), cacheService.hasCachedRoutes(),
      cacheService.hasCachedTrains()
    else { return false }

    try loadCachedData()
    return true
  }

  func subscribeToStationsUpdates() {
    print("🚂 TrainMapStore: Subscribing to stations from Convex...")
    print("🚂 TrainMapStore: Convex URL: \(Constants.Convex.deploymentUrl)")

    stationsCancellable?.cancel()
    stationsCancellable = convexClient.subscribe(to: "stations:get", yielding: [Station].self)
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            print("🚂 TrainMapStore: Stations subscription completed")
          case .failure(let error):
            print("🚂 TrainMapStore: Stations subscription error: \(error)")
          }
        },
        receiveValue: { [weak self] stations in
          guard let self else { return }
          print("🚂 TrainMapStore: Received \(stations.count) stations from Convex")
          self.stations = stations
          do {
            try self.cacheService.saveStations(stations)
          } catch {
            print("🚂 TrainMapStore: Failed to update cached stations: \(error)")
          }
        })
  }

  func getLastUpdatedTimestamp() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      var didResume = false
      var cancellable: AnyCancellable?

      cancellable = convexClient.subscribe(to: "gapeka:getLastUpdatedAt", yielding: String?.self)
        .sink(
          receiveCompletion: { completion in
            if case let .failure(error) = completion, !didResume {
              didResume = true
              continuation.resume(
                throwing: TrainMapError.convexConnectionFailed(error.localizedDescription))
            }
          },
          receiveValue: { timestamp in
            guard !didResume else { return }
            cancellable?.cancel()
            guard let timestamp else {
              didResume = true
              continuation.resume(
                throwing: TrainMapError.invalidDataFormat("Missing lastUpdatedAt timestamp"))
              return
            }

            didResume = true
            continuation.resume(returning: timestamp)
          })
    }
  }

  func fetchStationsFromConvex() async throws -> [Station] {
    try await withCheckedThrowingContinuation { continuation in
      var didResume = false
      var cancellable: AnyCancellable?

      cancellable = convexClient.subscribe(to: "stations:get", yielding: [Station].self)
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
    let routeLookupByNumeric = Dictionary(
      uniqueKeysWithValues: routes.compactMap { route -> (Int, Route)? in
        guard let identifier = route.numericIdentifier else { return nil }
        return (identifier, route)
      })

    let projected = rawTrains.compactMap { train in
      TrainProjector.projectTrain(
        now: now,
        train: train,
        stationsByCode: stationLookup,
        routesByIdentifier: routeLookupByIdentifier,
        routesByNumericIdentifier: routeLookupByNumeric
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

// MARK: - Mapping helpers
extension TrainMapStore {
  static var preview: TrainMapStore {
    let store = TrainMapStore(service: TrainMapService(httpClient: .development))
    store.stations = [
      Station(
        code: "GMR",
        name: "Gambir",
        position: Position(latitude: -6.1774, longitude: 106.8306),
        city: nil
      ),
      Station(
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
        numericIdentifier: 1
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
