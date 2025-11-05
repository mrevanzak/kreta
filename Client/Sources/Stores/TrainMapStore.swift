import Combine
import ConvexMobile
import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class TrainMapStore {
  private nonisolated(unsafe) let convexClient = Dependencies.shared.convexClient
  private let cacheService = TrainMapCacheService()
  private let liveActivityService = TrainLiveActivityService.shared

  var isLoading: Bool = false
  var selectedMapStyle: MapStyleOption = .hybrid
  var selectedTrain: ProjectedTrain? {
    didSet {
      Task { await persistSelectedTrain() }
    }
  }

  var stations: [Station] = []
  var routes: [Route] = []
  var lastUpdatedAt: String?

  var selectedJourneyData: TrainJourneyData? {
    didSet {
      Task { await persistJourneyData() }
    }
  }

  // Timestamp for triggering live position updates (must be observable)
  private var projectionTimestamp: Date = Date()

  // Scheduler ID for the scheduled trip reminder notification
  @ObservationIgnored private var scheduledNotificationId: String?

  var liveTrainPosition: ProjectedTrain? {
    guard selectedTrain != nil, selectedJourneyData != nil else { return nil }
    // Access projectionTimestamp to establish dependency for observation
    _ = projectionTimestamp
    return projectSelectedTrain(now: Date())
  }

  @ObservationIgnored private var projectionTimer: Timer?
  @ObservationIgnored private var lastUpdatedAtCancellable: AnyCancellable?

  let logger = Logger(subsystem: "kreta", category: String(describing: TrainMapStore.self))

  init() {

    // Load cached data immediately on init for instant display
    if (try? loadCachedDataIfAvailable()) != nil {
      logger.debug("Loaded cached data on initialization")
    }

    lastUpdatedAtCancellable = convexClient.subscribe(
      to: "gapeka:getLastUpdatedAt", yielding: String.self, captureTelemetry: true
    )
    .receive(on: DispatchQueue.main)
    .sink(
      receiveCompletion: { completion in
        switch completion {
        case .finished:
          self.logger.debug("LastUpdatedAt subscription completed")
        case .failure(let error):
          self.logger.error("LastUpdatedAt subscription error: \(error)")
        }
      },
      receiveValue: { lastUpdatedAt in
        self.logger.debug("Received lastUpdatedAt: \(lastUpdatedAt)")
        self.lastUpdatedAt = lastUpdatedAt
      })
  }

  func loadData(at timestamp: String) async throws {
    logger.debug("Starting loadData(at: \(timestamp))")

    isLoading = true
    defer { isLoading = false }

    stopProjectionUpdates()

    do {
      let cachedTimestamp = cacheService.getCachedTimestamp()
      logger.debug("Fetched cached timestamp: \(String(describing: cachedTimestamp))")

      let hasCompleteCache =
        cacheService.hasCachedStations()
        && cacheService.hasCachedRoutes()

      let needsUpdate = cachedTimestamp != timestamp || !hasCompleteCache

      if needsUpdate {
        logger.debug("Cache stale or missing. Fetching fresh data in parallel...")

        async let routesResult: [RoutePolyline] = Task { @MainActor in
          try await convexClient.query(to: "routes:list", yielding: [RoutePolyline].self)
        }.value
        async let stationsResult: [Station] = Task { @MainActor in
          try await convexClient.query(to: "station:list", yielding: [Station].self)
        }.value

        do {
          let routePolylines = try await routesResult
          logger.debug("Fetched \(routePolylines.count) routes")
          self.routes = routePolylines.map { Route(id: $0.id, name: $0.name, path: $0.path) }
          try cacheService.saveRoutes(routePolylines)
        } catch {
          logger.error("Routes fetch error: \(error)")
          throw TrainMapError.routesFetchFailed(error.localizedDescription)
        }

        do {
          let stations = try await stationsResult
          logger.debug("Fetched \(stations.count) stations")
          self.stations = stations
          try cacheService.saveStations(stations)
        } catch {
          logger.error("Stations fetch error: \(error)")
          throw TrainMapError.stationsFetchFailed(error.localizedDescription)
        }

      } else {
        logger.debug("Loading train map data from cache")
        try loadCachedData()
      }

      startProjectionUpdates()
      try cacheService.saveTimestamp(timestamp)

    } catch let error as TrainMapError {
      logger.error("TrainMapError encountered: \(error)")
      throw error
    } catch {
      logger.error("Unexpected error: \(error)")
      throw TrainMapError.dataMappingFailed(error.localizedDescription)
    }
  }
}

// MARK: - Data loading helpers
extension TrainMapStore {
  /// Start Live Activity from deep link parameters by resolving journey segments
  /// and constructing the required `ProjectedTrain` and `TrainJourneyData`.
  func startFromDeepLink(trainId: String, journeyId: String?) async throws {
    // Ensure stations and routes are loaded (attempt to load from cache if empty)
    if stations.isEmpty || routes.isEmpty {
      _ = try? loadCachedDataIfAvailable()
    }

    let journeyService = JourneyService()

    // Fetch segments for the provided train id
    let rows = try await journeyService.fetchSegmentsForTrain(trainId: trainId)

    guard !rows.isEmpty else {
      logger.error("No journey segments found for trainId: \(trainId)")
      return
    }

    // Build JourneySegments and collect stations along the full journey
    let stationsById = Dictionary(uniqueKeysWithValues: stations.map { ($0.id ?? $0.code, $0) })
    var journeySegments: [JourneySegment] = []
    var allStationsInJourney: [Station] = []

    for (index, segment) in rows.enumerated() {
      if let st = stationsById[segment.stationId] {
        allStationsInJourney.append(st)
      }

      if index < rows.count - 1 {
        let next = rows[index + 1]
        journeySegments.append(
          JourneySegment(
            fromStationId: segment.stationId,
            toStationId: next.stationId,
            departure: segment.departure,
            arrival: next.arrival,
            routeId: next.routeId
          )
        )
      }
    }

    // Derive front-facing info for ProjectedTrain
    let first = rows.first!
    let last = rows.last!
    let fromStation = stationsById[first.stationId]
    let toStation = stationsById[last.stationId]

    let projected = ProjectedTrain(
      id: trainId,
      code: first.trainCode,
      name: first.trainName,
      position: Position(
        latitude: fromStation?.position.latitude ?? 0,
        longitude: fromStation?.position.longitude ?? 0
      ),
      moving: false,
      bearing: nil,
      routeIdentifier: last.routeId,
      speedKph: nil,
      fromStation: fromStation,
      toStation: toStation,
      segmentDeparture: first.departure,
      segmentArrival: last.arrival,
      progress: nil,
      journeyDeparture: first.departure,
      journeyArrival: last.arrival
    )

    // Resolve required user-selected leg details for the new TrainJourneyData
    guard let resolvedFromStation = fromStation, let resolvedToStation = toStation else {
      logger.error("Missing station mapping for user-selected leg in TrainJourneyData")
      return
    }

    let userSelectedDepartureTime = first.departure
    let userSelectedArrivalTime = last.arrival

    let journeyData = TrainJourneyData(
      trainId: trainId,
      segments: journeySegments,
      allStations: allStationsInJourney,
      userSelectedFromStation: resolvedFromStation,
      userSelectedToStation: resolvedToStation,
      userSelectedDepartureTime: userSelectedDepartureTime,
      userSelectedArrivalTime: userSelectedArrivalTime
    )

    // Persist and start
    try await selectTrain(projected, journeyData: journeyData)
  }
  fileprivate func loadCachedData() throws {
    stations = try cacheService.loadCachedStations()
    let routePolylines = try cacheService.loadCachedRoutes()
    routes = routePolylines.map { Route(id: $0.id, name: $0.name, path: $0.path) }
  }

  fileprivate func loadCachedDataIfAvailable() throws -> Bool {
    guard cacheService.hasCachedStations(), cacheService.hasCachedRoutes()
    else { return false }

    try loadCachedData()
    return true
  }
}

// MARK: - Projection management
extension TrainMapStore {
  func startProjectionUpdates(interval: TimeInterval = 1.0) {
    stopProjectionUpdates()
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        // Update timestamp to trigger liveTrainPosition recalculation
        self.projectionTimestamp = Date()
      }
    }
    projectionTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func stopProjectionUpdates() {
    projectionTimer?.invalidate()
    projectionTimer = nil
  }
}

// MARK: - Selected train management
extension TrainMapStore {
  func selectTrain(_ train: ProjectedTrain, journeyData: TrainJourneyData) async throws {
    selectedTrain = train
    selectedJourneyData = journeyData
    startProjectionUpdates()

    // Start Live Activity
    try await startLiveActivityForTrain(train: train, journeyData: journeyData)

    // Track journey start
    if let from = train.fromStation, let to = train.toStation {
      AnalyticsEventService.shared.trackJourneyStarted(
        trainId: journeyData.trainId,
        trainName: train.name,
        from: from,
        to: to,
        userSelectedDeparture: journeyData.userSelectedDepartureTime,
        userSelectedArrival: journeyData.userSelectedArrivalTime,
        hasAlarmEnabled: AlarmPreferences.shared.defaultAlarmEnabled
      )
    }
  }

  private func startLiveActivityForTrain(train: ProjectedTrain, journeyData: TrainJourneyData)
    async throws
  {
    guard let fromStation = train.fromStation,
      let toStation = train.toStation,
      let departureTime = train.segmentDeparture
    else {
      logger.error("Missing required data for Live Activity")
      return
    }

    let timeUntilDeparture = departureTime.timeIntervalSinceNow
    let scheduleOffset: TimeInterval = 10 * 60  // 10 minutes
    let now = Date()
    let isInProgress =
      (journeyData.userSelectedDepartureTime...journeyData.userSelectedArrivalTime).contains(now)

    if timeUntilDeparture <= scheduleOffset {
      // Start immediately on device
      logger.info(
        "Starting Live Activity immediately (departure in \(timeUntilDeparture / 60) minutes)")

      // TODO: Replace hardcoded seat class with actual user data
      try await liveActivityService.start(
        trainName: train.name,
        from: TrainStation(
          name: fromStation.name,
          code: fromStation.code,
          estimatedTime: departureTime
        ),
        destination: TrainStation(
          name: toStation.name,
          code: toStation.code,
          estimatedTime: train.segmentArrival
        ),
        // seatClass: .economy(number: 1),  // TODO: Replace with actual seat class
        // seatNumber: "1A",  // TODO: Replace with actual seat number
        initialJourneyState: isInProgress ? .onBoard : nil
      )
    } else {
      logger.info(
        "Queuing trip reminder notification (departure in \(timeUntilDeparture / 60) minutes)")

      try await queueTripReminderNotification(
        train: train,
        fromStation: fromStation,
        toStation: toStation,
        departureTime: departureTime
      )
    }
  }

  private func queueTripReminderNotification(
    train: ProjectedTrain,
    fromStation: Station,
    toStation: Station,
    departureTime: Date
  ) async throws {
    guard let deviceToken = PushRegistrationService.shared.currentToken() else {
      logger.error("No device token available for queuing trip reminder")
      throw TrainMapError.missingDeviceToken
    }

    var fromEstimatedTime: Double? = nil
    if let departureTime = train.segmentDeparture {
      fromEstimatedTime = departureTime.timeIntervalSince1970 * 1000
    }

    var destinationEstimatedTime: Double? = nil
    if let arrivalTime = train.segmentArrival {
      destinationEstimatedTime = arrivalTime.timeIntervalSince1970 * 1000
    }

    let schedulerId: String = try await convexClient.mutation(
      "notifications:scheduleTripReminder",
      with: [
        "deviceToken": deviceToken as ConvexEncodable,
        "trainId": train.id as ConvexEncodable,
        "trainName": train.name as ConvexEncodable,
        "departureTime": (departureTime.timeIntervalSince1970 * 1000) as ConvexEncodable,  // Convert seconds to milliseconds
        "fromStation": [
          "name": fromStation.name as ConvexEncodable,
          "code": fromStation.code as ConvexEncodable,
          "estimatedTime": fromEstimatedTime as ConvexEncodable?,
        ] as ConvexEncodable,
        "destinationStation": [
          "name": toStation.name as ConvexEncodable,
          "code": toStation.code as ConvexEncodable,
          "estimatedTime": destinationEstimatedTime as ConvexEncodable?,
        ] as ConvexEncodable,
      ],
      captureTelemetry: true
    )

    scheduledNotificationId = schedulerId
    logger.info(
      "Successfully scheduled trip reminder notification with scheduler ID: \(schedulerId)")
  }

  func clearSelectedTrain() async {
    // Evaluate completion vs cancellation before clearing
    if let train = selectedTrain, let data = selectedJourneyData {
      let now = Date()
      if now < data.userSelectedArrivalTime {
        AnalyticsEventService.shared.trackJourneyCancelled(
          trainId: data.trainId,
          reason: "ended_before_arrival",
          context: [
            "expected_arrival_time": ISO8601DateFormatter().string(from: data.userSelectedArrivalTime),
            "train_name": train.name,
          ]
        )
      } else {
        AnalyticsEventService.shared.trackJourneyCompleted(
          trainId: data.trainId,
          from: data.userSelectedFromStation,
          to: data.userSelectedToStation,
          userSelectedDeparture: data.userSelectedDepartureTime,
          completionType: "scheduled_arrival",
          actualArrival: now,
          wasTrackedUntilArrival: true
        )
      }
    }

    // End live activities and cancel alarms for the selected train
    if let selectedTrain = selectedTrain {
      let activeActivities = liveActivityService.getActiveLiveActivities()

      // Find matching activity by train name and stations
      for activity in activeActivities {
        let matchesTrainName = activity.attributes.trainName == selectedTrain.name
        let matchesFromStation =
          activity.attributes.from.code == selectedTrain.fromStation?.code
          || activity.attributes.from.name == selectedTrain.fromStation?.name
        let matchesDestination =
          activity.attributes.destination.code == selectedTrain.toStation?.code
          || activity.attributes.destination.name == selectedTrain.toStation?.name

        if matchesTrainName && matchesFromStation && matchesDestination {
          logger.info("Ending live activity \(activity.id) for train \(selectedTrain.name)")
          await liveActivityService.end(activityId: activity.id)
          break  // Only end one matching activity
        }
      }
    }

    // Cancel any pending trip reminders on server
    if let schedulerId = scheduledNotificationId {
      do {
        let _: String = try await convexClient.mutation(
          "notifications:cancelTripReminder",
          with: ["schedulerId": schedulerId as ConvexEncodable],
          captureTelemetry: true
        )
        logger.info("Cancelled scheduled trip reminder with scheduler ID: \(schedulerId)")
        scheduledNotificationId = nil
      } catch {
        logger.error("Failed to cancel scheduled trip reminder: \(error)")
      }
    }

    selectedTrain = nil
    selectedJourneyData = nil
  }

  func loadSelectedTrainFromCache() async throws {
    selectedTrain = try cacheService.loadSelectedTrain()
    selectedJourneyData = try cacheService.loadJourneyData()
  }

  private func persistSelectedTrain() async {
    do {
      try cacheService.saveSelectedTrain(selectedTrain)
    } catch {
      logger.error("Failed to save selected train: \(error)")
    }
  }

  private func persistJourneyData() async {
    do {
      try cacheService.saveJourneyData(selectedJourneyData)
    } catch {
      logger.error("Failed to save journey data: \(error)")
    }
  }

  private func projectSelectedTrain(now: Date = Date()) -> ProjectedTrain? {
    guard let selectedTrain, let selectedJourneyData else { return nil }

    let stationsById = Dictionary(
      uniqueKeysWithValues: stations.map { ($0.id ?? $0.code, $0) })
    let routesById = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })

    let trainJourney = TrainJourney(
      id: selectedTrain.id,
      trainId: selectedTrain.id,
      code: selectedTrain.code,
      name: selectedTrain.name,
      segments: selectedJourneyData.segments
    )

    return TrainProjector.projectTrain(
      now: now,
      journey: trainJourney,
      stationsById: stationsById,
      routesById: routesById
    )
  }
}

// MARK: - Mapping helpers
extension TrainMapStore {
  static var preview: TrainMapStore {
    let store = TrainMapStore()
    store.stations = [
      Station(
        id: "GMR",
        code: "GMR",
        name: "Gambir",
        position: Position(latitude: -6.1774, longitude: 106.8306),
        city: nil
      ),
      Station(
        id: "JNG",
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
        ],
      )
    ]
    return store
  }
}
