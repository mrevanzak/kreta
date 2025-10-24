import Foundation

struct TrainMapService {
  let httpClient: HTTPClient

  init(httpClient: HTTPClient) {
    self.httpClient = httpClient
  }

  func fetchRoutes() async throws -> [Route] {
    // API returns a dictionary keyed by route id → Node
    let resource = Resource(
      url: Constants.TrainMap.routes, method: .post(nil), modelType: [String: RawRouteNode].self)
    let raw = try await httpClient.load(resource)
    // Map each node into a single Route polyline using `coordinates` if present,
    // otherwise flatten all Path.pos segments
    return raw.map { key, node in node.asRoute(id: key) }.compactMap { $0 }
  }

  func fetchTrainPositions() async throws -> [RawGapekaTrain] {
    let resource = Resource(
      url: Constants.TrainMap.positions, method: .post(nil), modelType: [RawGapekaTrain].self)
    return try await httpClient.load(resource)
  }
}
