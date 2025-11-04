import Disk
import Foundation

struct TrainMapCacheService {
  private let cacheFolder = "TrainMapCache"
  private let stationsFile = "stations.json"
  private let routesFile = "routes.json"
  private let journeyFile = "journey.json"
  private let timestampFile = "lastUpdatedAt.txt"
  private let selectedTrainFile = "selectedTrain.json"
  private let journeyDataFile = "journeyData.json"

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

  // MARK: - Selected Train

  func saveSelectedTrain(_ train: ProjectedTrain?) throws {
    if let train = train {
      try Disk.save(train, to: .applicationSupport, as: "\(cacheFolder)/\(selectedTrainFile)")
    } else {
      // Clear cache by deleting file
      let url = try Disk.url(for: "\(cacheFolder)/\(selectedTrainFile)", in: .applicationSupport)
      try? FileManager.default.removeItem(at: url)
    }
  }

  func loadSelectedTrain() throws -> ProjectedTrain? {
    guard Disk.exists("\(cacheFolder)/\(selectedTrainFile)", in: .applicationSupport) else {
      return nil
    }
    return try Disk.retrieve(
      "\(cacheFolder)/\(selectedTrainFile)", from: .applicationSupport, as: ProjectedTrain.self)
  }

  // MARK: - Journey Data

  func saveJourneyData(_ data: TrainJourneyData?) throws {
    if let data = data {
      try Disk.save(data, to: .applicationSupport, as: "\(cacheFolder)/\(journeyDataFile)")
    } else {
      // Clear cache by deleting file
      let url = try Disk.url(for: "\(cacheFolder)/\(journeyDataFile)", in: .applicationSupport)
      try? FileManager.default.removeItem(at: url)
    }
  }

  func loadJourneyData() throws -> TrainJourneyData? {
    guard Disk.exists("\(cacheFolder)/\(journeyDataFile)", in: .applicationSupport) else {
      return nil
    }
    return try Disk.retrieve(
      "\(cacheFolder)/\(journeyDataFile)", from: .applicationSupport, as: TrainJourneyData.self)
  }
}
