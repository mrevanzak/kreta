import Foundation
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private let service: TrainMapService

  var stations: [Station] = []
  var routes: [Route] = []
  var trains: [LiveTrain] = []
  var isLoading: Bool = false

  init(service: TrainMapService) {
    self.service = service
  }

  func loadInitial() async throws {
    isLoading = true
    defer { isLoading = false }
    async let s = service.fetchStations()
    async let r = service.fetchRoutes()
    async let t = service.fetchTrainPositions()
    let (stations, routes, trains) = try await (s, r, t)
    self.stations = stations
    self.routes = routes
    self.trains = Self.mapGapekaToLiveTrains(trains, stations: stations)
  }

  // func refreshTrains() async throws {
  //   let raw = try await service.fetchTrainPositions()
  //   self.trains = Self.mapGapekaToPositions(raw, stations: stations)
  // }
}

// MARK: - Mapping helpers
extension TrainMapStore {
  fileprivate static func mapGapekaToLiveTrains(_ raw: [RawGapekaTrain], stations: [Station])
    -> [LiveTrain]
  {
    let stationByCode: [String: Station] = Dictionary(
      uniqueKeysWithValues: stations.map { ($0.code, $0) })

    func haversine(_ a: Station, _ b: Station) -> Double {
      let lat1 = a.position.latitude * .pi / 180
      let lon1 = a.position.longitude * .pi / 180
      let lat2 = b.position.latitude * .pi / 180
      let lon2 = b.position.longitude * .pi / 180
      let dLat = lat2 - lat1
      let dLon = lon2 - lon1
      let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
      let c = 2 * atan2(sqrt(h), sqrt(1 - h))
      let earthRadiusKm = 6371.0
      return earthRadiusKm * c
    }

    func bearing(from a: Station, to b: Station) -> Double {
      let lat1 = a.position.latitude * .pi / 180
      let lon1 = a.position.longitude * .pi / 180
      let lat2 = b.position.latitude * .pi / 180
      let lon2 = b.position.longitude * .pi / 180
      let y = sin(lon2 - lon1) * cos(lat2)
      let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)
      let brng = atan2(y, x) * 180 / .pi
      return fmod((brng + 360), 360)
    }

    var results: [LiveTrain] = []
    for train in raw {
      // Use the current segment between nearest depart<=now<next.arriv (based on ms timestamps)
      let nowMs = Date().timeIntervalSince1970 * 1000
      let sorted = train.paths.sorted { $0.departMs < $1.departMs }
      guard
        let idx = sorted.firstIndex(where: { $0.departMs <= nowMs && nowMs < $0.arrivMs })
          ?? sorted.firstIndex(where: { nowMs < $0.arrivMs }) ?? sorted.indices.last
      else {
        continue
      }
      let segment = sorted[idx]
      guard let from = stationByCode[segment.orgStCd] ?? stationByCode[segment.stCd],
        let to = stationByCode[segment.stCd] ?? stationByCode[segment.orgStCd]
      else {
        continue
      }

      let start = segment.departMs
      let end = segment.arrivMs
      let progress: Double
      if end > start {
        progress = min(1, max(0, (nowMs - start) / (end - start)))
      } else {
        progress = 0
      }

      let lat = from.position.latitude + (to.position.latitude - from.position.latitude) * progress
      let lon =
        from.position.longitude
        + (to.position.longitude - from.position.longitude) * progress
      let brg = bearing(from: from, to: to)

      var speed: Double? = nil
      let distanceKm = haversine(from, to)
      let hours = (end - start) / 3_600_000.0
      if hours > 0 { speed = distanceKm / hours }

      let id = "\(train.trCd)-\(idx)"
      results.append(
        LiveTrain(id: id, latitude: lat, longitude: lon, bearing: brg, speedKph: speed))
    }
    return results
  }
}

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
      LiveTrain(id: "T1", latitude: -6.1950, longitude: 106.8500, bearing: 45, speedKph: 60)
    ]
    return store
  }
}
