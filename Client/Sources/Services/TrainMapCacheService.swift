import Disk
import Foundation

struct TrainMapCacheService {
  private let cacheFolder = "TrainMapCache"
  private let stationsFile = "stations.json"
  private let routesFile = "routes.json"
  private let trainsFile = "trains.json"
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
  func saveRoutes(_ routes: [Route]) throws {
    try Disk.save(routes, to: .applicationSupport, as: "\(cacheFolder)/\(routesFile)")
  }

  func loadCachedRoutes() throws -> [Route] {
    try Disk.retrieve("\(cacheFolder)/\(routesFile)", from: .applicationSupport, as: [Route].self)
  }

  func hasCachedRoutes() -> Bool {
    Disk.exists("\(cacheFolder)/\(routesFile)", in: .applicationSupport)
  }

  // MARK: - Trains
  func saveTrains(_ trains: [RawGapekaTrain]) throws {
    try Disk.save(trains, to: .applicationSupport, as: "\(cacheFolder)/\(trainsFile)")
  }

  func loadCachedTrains() throws -> [RawGapekaTrain] {
    try Disk.retrieve(
      "\(cacheFolder)/\(trainsFile)", from: .applicationSupport, as: [RawGapekaTrain].self)
  }

  func hasCachedTrains() -> Bool {
    Disk.exists("\(cacheFolder)/\(trainsFile)", in: .applicationSupport)
  }
}
