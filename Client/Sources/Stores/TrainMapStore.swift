import Foundation
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private let service: TrainMapService

  var stations: [Station] = []
  var routes: [TrainLine] = []
  var trains: [TrainPosition] = []
  var isLoading: Bool = false
  var errorMessage: String?

  init(service: TrainMapService) {
    self.service = service
  }

  func loadInitial() async {
    isLoading = true
    errorMessage = nil
    do {
      async let s = service.fetchStations()
      async let r = service.fetchRoutes()
      async let rawTrains = service.fetchTrainPositions()
      let (stations, routes, trainsRaw) = try await (s, r, rawTrains)
      self.stations = stations
      self.routes = routes
      self.trains = Self.mapGapekaToPositions(trainsRaw, stations: stations)
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }

  func refreshTrains() async {
    do {
      let raw = try await service.fetchTrainPositions()
      self.trains = Self.mapGapekaToPositions(raw, stations: stations)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

// MARK: - Mapping helpers
extension TrainMapStore {
  fileprivate static func mapGapekaToPositions(_ raw: [RawGapekaTrain], stations: [Station])
    -> [TrainPosition]
  {
    let stationByCode: [String: Station] = Dictionary(
      uniqueKeysWithValues: stations.map { ($0.code, $0) })

    func haversine(_ a: Station, _ b: Station) -> Double {
      let lat1 = a.latitude * .pi / 180
      let lon1 = a.longitude * .pi / 180
      let lat2 = b.latitude * .pi / 180
      let lon2 = b.longitude * .pi / 180
      let dLat = lat2 - lat1
      let dLon = lon2 - lon1
      let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
      let c = 2 * atan2(sqrt(h), sqrt(1 - h))
      let earthRadiusKm = 6371.0
      return earthRadiusKm * c
    }

    func bearing(from a: Station, to b: Station) -> Double {
      let lat1 = a.latitude * .pi / 180
      let lon1 = a.longitude * .pi / 180
      let lat2 = b.latitude * .pi / 180
      let lon2 = b.longitude * .pi / 180
      let y = sin(lon2 - lon1) * cos(lat2)
      let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)
      let brng = atan2(y, x) * 180 / .pi
      return fmod((brng + 360), 360)
    }

    var results: [TrainPosition] = []
    for train in raw {
      // Use the current segment between nearest depart<=now<next.arriv (based on ms timestamps)
      let nowMs = Int(Date().timeIntervalSince1970 * 1000)
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
        progress = min(1, max(0, Double(nowMs - start) / Double(end - start)))
      } else {
        progress = 0
      }

      let lat = from.latitude + (to.latitude - from.latitude) * progress
      let lon = from.longitude + (to.longitude - from.longitude) * progress
      let brg = bearing(from: from, to: to)

      var speed: Double? = nil
      let distanceKm = haversine(from, to)
      let hours = Double(end - start) / 3_600_000.0
      if hours > 0 { speed = distanceKm / hours }

      let id = "\(train.trCd)-\(idx)"
      results.append(
        TrainPosition(id: id, latitude: lat, longitude: lon, bearing: brg, speedKph: speed))
    }
    return results
  }
}

extension TrainMapStore {
  static var preview: TrainMapStore {
    let store = TrainMapStore(service: TrainMapService(httpClient: .development))
    store.stations = [
      Station(code: "GMR", name: "Gambir", latitude: -6.1774, longitude: 106.8306),
      Station(code: "JNG", name: "Jatinegara", latitude: -6.2149, longitude: 106.8707),
    ]
    store.routes = [
      TrainLine(
        id: "L1",
        name: "Central Line",
        path: [
          [-6.1774, 106.8306],
          [-6.1900, 106.8450],
          [-6.2050, 106.8600],
          [-6.2149, 106.8707],
        ]
      )
    ]
    store.trains = [
      TrainPosition(id: "T1", latitude: -6.1950, longitude: 106.8500, bearing: 45, speedKph: 60)
    ]
    return store
  }
}
