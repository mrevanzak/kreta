import Foundation

struct TrainMapService {
  let httpClient: HTTPClient

  init(httpClient: HTTPClient) {
    self.httpClient = httpClient
  }

  func fetchStations() async throws -> [Station] {
    // API returns a dictionary keyed by numeric strings, e.g., { "3": { cd, nm, coordinates } }
    let resource = Resource(
      url: Constants.TrainMap.stations, method: .post(nil), modelType: [String: RawStation].self)
    let raw = try await httpClient.load(resource)
    return raw.values.compactMap { $0.asStation }
  }

  func fetchRoutes() async throws -> [TrainLine] {
    // API returns a dictionary keyed by route id → Node
    let resource = Resource(
      url: Constants.TrainMap.routes, method: .post(nil), modelType: [String: RawRouteNode].self)
    let raw = try await httpClient.load(resource)
    // Map each node into a single TrainLine polyline using `coordinates` if present,
    // otherwise flatten all Path.pos segments
    return raw.map { key, node in node.asTrainLine(id: key) }.compactMap { $0 }
  }

  func fetchTrainPositions() async throws -> [RawGapekaTrain] {
    let resource = Resource(
      url: Constants.TrainMap.positions, method: .post(nil), modelType: [RawGapekaTrain].self)
    return try await httpClient.load(resource)
  }
}
