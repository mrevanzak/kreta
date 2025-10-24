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
    isLoading = true
    defer { isLoading = false }

    // Start subscription to stations
    startStationsSubscription()

    // Fetch routes and train positions
    async let r = service.fetchRoutes()
    async let t = service.fetchTrainPositions()
    let (routes, raw) = try await (r, t)

    self.routes = routes
    self.rawTrains = raw
  }

  private func startStationsSubscription() {
    stationsCancellable = convexClient.subscribe(
      to: "stations:get",
      yielding: [Station].self
    )
    .replaceError(with: [])
    .sink { [weak self] newStations in
      guard let self = self else { return }
      self.stations = newStations
      // Update trains when stations change
      // if !self.rawTrains.isEmpty {
      //   self.trains = Self.mapGapekaToLiveTrains(self.rawTrains, stations: newStations)
      // }
    }
  }

  // func refreshTrains() async throws {
  //   let raw = try await service.fetchTrainPositions()
  //   self.trains = Self.mapGapekaToPositions(raw, stations: stations)
  // }
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
