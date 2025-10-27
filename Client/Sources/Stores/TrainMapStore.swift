import Combine
import Foundation
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private let service: TrainMapService
  private let convexClient = Dependencies.shared.convexClient

  var isLoading: Bool = false

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
      // Subscribe to stations from Convex
      print("🚂 TrainMapStore: Subscribing to stations from Convex...")
      print("🚂 TrainMapStore: Convex URL: \(Constants.Convex.deploymentUrl)")

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
          receiveValue: { stations in
            print("🚂 TrainMapStore: Received \(stations.count) stations from Convex")
            self.stations = stations
          })

      // Fetch routes and train positions concurrently
      print("🚂 TrainMapStore: Fetching routes and train positions...")

      async let routesTask: Void = {
        do {
          let routes = try await service.fetchRoutes()
          print("🚂 TrainMapStore: Fetched \(routes.count) routes")
          await MainActor.run {
            self.routes = routes
          }
        } catch {
          print("🚂 TrainMapStore: Routes fetch error: \(error)")
          throw TrainMapError.routesFetchFailed(error.localizedDescription)
        }
      }()

      async let trainsTask: Void = {
        do {
          let raw = try await service.fetchTrainPositions()
          print("🚂 TrainMapStore: Fetched \(raw.count) trains")
          await MainActor.run {
            self.rawTrains = raw
          }
        } catch {
          print("🚂 TrainMapStore: Train positions fetch error: \(error)")
          throw TrainMapError.trainPositionsFetchFailed(error.localizedDescription)
        }
      }()

      // Wait for both tasks to complete
      try await routesTask
      try await trainsTask

      projectTrains()
      startProjectionUpdates()

    } catch let error as TrainMapError {
      // Re-throw TrainMapError as-is
      throw error
    } catch {
      // Wrap other errors
      print("🚂 TrainMapStore: Unexpected error: \(error)")
      throw TrainMapError.dataMappingFailed(error.localizedDescription)
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
