import Combine
import Foundation
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private let service: TrainMapService
  private let convexClient = Dependencies.shared.convexClient

  var isLoading: Bool = false

  var stations: [Station] = []
  var routes: [Route] = []
  var trains: [LiveTrain] = []
  private var rawTrains: [RawGapekaTrain] = []

  private var stationsCancellable: AnyCancellable?

  init(service: TrainMapService) {
    self.service = service
  }

  func loadInitial() async throws {
    print("🚂 TrainMapStore: Starting loadInitial()")

    isLoading = true
    defer { isLoading = false }

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

    // Fetch routes and train positions
    print("🚂 TrainMapStore: Fetching routes and train positions...")
    async let r = service.fetchRoutes()
    async let t = service.fetchTrainPositions()
    let (routes, raw) = try await (r, t)
    print("🚂 TrainMapStore: Fetched \(routes.count) routes and \(raw.count) trains")

    self.routes = routes
    self.rawTrains = raw
    print("🚂 TrainMapStore: loadInitial() completed")
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
        ]
      )
    ]
    store.trains = [
      LiveTrain(
        id: "T1-0",
        code: "T1",
        name: "Sample Express",
        position: Position(latitude: -6.1950, longitude: 106.8500),
        bearing: 45,
        speedKph: 60,
        fromStation: store.stations[0],
        toStation: store.stations[1],
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
