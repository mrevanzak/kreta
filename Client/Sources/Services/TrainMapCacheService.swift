import Disk
import Foundation

struct TrainMapCacheService {
  private let cacheFolder = "TrainMapCache"
  private let stationsFile = "stations.json"
  private let routesFile = "routes.json"
  private let journeyFile = "journey.json"
  private let timestampFile = "lastUpdatedAt.txt"

  // MARK: - Timestamp
  func getCachedTimestamp() -> String? {
    do {
      let url = try Disk.url(for: "\(cacheFolder)/\(timestampFile)", in: .applicationSupport)
      return try String(contentsOf: url, encoding: .utf8)
    } catch {
      return nil
    }
  }

  func saveTimestamp(_ timestamp: String) throws {
    let url = try Disk.url(for: "\(cacheFolder)/\(timestampFile)", in: .applicationSupport)
    try timestamp.write(to: url, atomically: true, encoding: .utf8)
  }

  // MARK: - Stations
  func saveStations(_ stations: [Station]) throws {
    try Disk.save(stations, to: .applicationSupport, as: "\(cacheFolder)/\(stationsFile)")
  }

  func loadCachedStations() throws -> [Station] {
    try Disk.retrieve(
      "\(cacheFolder)/\(stationsFile)", from: .applicationSupport, as: [Station].self)
  }

  func hasCachedStations() -> Bool {
    Disk.exists("\(cacheFolder)/\(stationsFile)", in: .applicationSupport)
  }

  // MARK: - Routes
  func saveRoutes(_ routes: [RoutePolyline]) throws {
    try Disk.save(routes, to: .applicationSupport, as: "\(cacheFolder)/\(routesFile)")
  }

  func loadCachedRoutes() throws -> [RoutePolyline] {
    try Disk.retrieve(
      "\(cacheFolder)/\(routesFile)", from: .applicationSupport, as: [RoutePolyline].self)
  }

  func hasCachedRoutes() -> Bool {
    Disk.exists("\(cacheFolder)/\(routesFile)", in: .applicationSupport)
  }

  // MARK: - Journeys
  func saveJourney(_ journey: TrainJourney) throws {
    try Disk.save(journey, to: .applicationSupport, as: "\(cacheFolder)/\(journeyFile)")
  }

  func loadCachedJourney() throws -> TrainJourney {
    try Disk.retrieve(
      "\(cacheFolder)/\(journeyFile)", from: .applicationSupport, as: TrainJourney.self)
  }

  func hasCachedJourney() -> Bool {
    Disk.exists("\(cacheFolder)/\(journeyFile)", in: .applicationSupport)
  }
}
