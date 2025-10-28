import Foundation

struct TrainMapCacheService {
  private let fileManager = FileManager.default

  private var cacheDirectory: URL {
    fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("TrainMapCache", isDirectory: true)
  }

  private var stationsURL: URL { cacheDirectory.appendingPathComponent("stations.json") }
  private var routesURL: URL { cacheDirectory.appendingPathComponent("routes.json") }
  private var trainsURL: URL { cacheDirectory.appendingPathComponent("trains.json") }
  private var timestampURL: URL { cacheDirectory.appendingPathComponent("lastUpdatedAt.txt") }

  init() {
    try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
  }

  // MARK: - Timestamp

  func getCachedTimestamp() -> String? {
    try? String(contentsOf: timestampURL, encoding: .utf8)
  }

  func saveTimestamp(_ timestamp: String) throws {
    try timestamp.write(to: timestampURL, atomically: true, encoding: .utf8)
  }

  // MARK: - Stations

  func saveStations(_ stations: [Station]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(stations)
    try data.write(to: stationsURL, options: .atomic)
  }

  func loadCachedStations() throws -> [Station] {
    let data = try Data(contentsOf: stationsURL)
    return try JSONDecoder().decode([Station].self, from: data)
  }

  func hasCachedStations() -> Bool {
    fileManager.fileExists(atPath: stationsURL.path)
  }

  // MARK: - Routes

  func saveRoutes(_ routes: [Route]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(routes)
    try data.write(to: routesURL, options: .atomic)
  }

  func loadCachedRoutes() throws -> [Route] {
    let data = try Data(contentsOf: routesURL)
    return try JSONDecoder().decode([Route].self, from: data)
  }

  func hasCachedRoutes() -> Bool {
    fileManager.fileExists(atPath: routesURL.path)
  }

  // MARK: - Trains

  func saveTrains(_ trains: [RawGapekaTrain]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(trains)
    try data.write(to: trainsURL, options: .atomic)
  }

  func loadCachedTrains() throws -> [RawGapekaTrain] {
    let data = try Data(contentsOf: trainsURL)
    return try JSONDecoder().decode([RawGapekaTrain].self, from: data)
  }

  func hasCachedTrains() -> Bool {
    fileManager.fileExists(atPath: trainsURL.path)
  }
}
