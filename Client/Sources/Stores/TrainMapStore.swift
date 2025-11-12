import Combine
import ConvexMobile
import Foundation
import OSLog
import Observation
import UserNotifications

@MainActor
@Observable
final class TrainMapStore {
  private nonisolated(unsafe) let convexClient = Dependencies.shared.convexClient
  private let cacheService = TrainMapCacheService()
  private let liveActivityService = TrainLiveActivityService.shared
  private let configStore = ConfigStore.shared
  @ObservationIgnored private let notificationCenter = UNUserNotificationCenter.current()

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

  @ObservationIgnored private var scheduledTripReminderRequestId: String?

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
    guard let scheduleOffset = configStore.appConfig?.tripReminder else {
      logger.error("No trip remainder config found")
      return
    }

    if timeUntilDeparture <= scheduleOffset {
      cancelPendingTripReminder()
      // Start immediately on device
      logger.info(
        "Starting Live Activity immediately (departure in \(timeUntilDeparture / 60) minutes)")
      try await executeLiveActivityStart(train: train, journeyData: journeyData)
    } else {
      logger.info(
        "Queuing trip reminder notification (departure in \(timeUntilDeparture / 60) minutes)")

      try await scheduleTripReminderNotification(
        train: train,
        fromStation: fromStation,
        toStation: toStation,
        departureTime: departureTime,
        scheduleOffset: scheduleOffset
      )
    }
  }

  /// Execute Live Activity start and alarm scheduling logic
  /// This is the core logic that should be executed regardless of timing
  private func executeLiveActivityStart(
    train: ProjectedTrain,
    journeyData: TrainJourneyData
  ) async throws {
    guard let fromStation = train.fromStation,
      let toStation = train.toStation,
      let departureTime = train.segmentDeparture
    else {
      logger.error("Missing required data for Live Activity")
      return
    }

    let now = Date()
    let isInProgress =
      (journeyData.userSelectedDepartureTime...journeyData.userSelectedArrivalTime).contains(now)

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
  }

  private func scheduleTripReminderNotification(
    train: ProjectedTrain,
    fromStation: Station,
    toStation: Station,
    departureTime: Date,
    scheduleOffset: TimeInterval
  ) async throws {
    let reminderDate = departureTime.addingTimeInterval(-scheduleOffset)

    guard reminderDate > Date() else {
      logger.info("Trip reminder would fire in the past; skipping local scheduling")
      return
    }

    cancelPendingTripReminder()

    let content = UNMutableNotificationContent()
    content.title = "Perjalanan akan dimulai"
    content.body =
      "Kereta \(train.name) akan berangkat dalam 10 menit dari \(fromStation.name). Buka aplikasi untuk mulai melacak perjalanan."
    content.sound = .default
    content.categoryIdentifier = "TRIP_START_FALLBACK"
    content.interruptionLevel = .timeSensitive

    if let deepLink = makeTripReminderDeepLink(
      trainId: train.id,
      fromCode: fromStation.code,
      toCode: toStation.code
    ) {
      content.userInfo = ["deeplink": deepLink]
    }

    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: reminderDate
    )

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let requestId = makeTripReminderIdentifier(for: train.id, departureTime: departureTime)
    let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

    try await addNotificationRequest(request)
    scheduledTripReminderRequestId = requestId

    logger.info(
      "Scheduled local trip reminder notification for train \(train.name) at \(reminderDate.timeIntervalSince1970)"
    )
  }

  private func addNotificationRequest(_ request: UNNotificationRequest) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      notificationCenter.add(request) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }

  private func cancelPendingTripReminder() {
    guard let requestId = scheduledTripReminderRequestId else { return }
    notificationCenter.removePendingNotificationRequests(withIdentifiers: [requestId])
    notificationCenter.removeDeliveredNotifications(withIdentifiers: [requestId])
    scheduledTripReminderRequestId = nil
    logger.info("Cancelled pending local trip reminder notification with identifier \(requestId)")
  }

  private func makeTripReminderIdentifier(for trainId: String, departureTime: Date) -> String {
    "trip_reminder_\(trainId)_\(Int(departureTime.timeIntervalSince1970))"
  }

  private func makeTripReminderDeepLink(trainId: String, fromCode: String, toCode: String)
    -> String?
  {
    var components = URLComponents()
    components.scheme = "kreta"
    components.host = "trip"
    components.path = "/start"
    components.queryItems = [
      URLQueryItem(name: "trainId", value: trainId),
      URLQueryItem(name: "fromCode", value: fromCode),
      URLQueryItem(name: "toCode", value: toCode),
    ]
    return components.url?.absoluteString
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
            "expected_arrival_time": ISO8601DateFormatter().string(
              from: data.userSelectedArrivalTime),
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

    cancelPendingTripReminder()

    selectedTrain = nil
    selectedJourneyData = nil
  }

  func loadSelectedTrainFromCache() async throws {
    selectedTrain = try cacheService.loadSelectedTrain()
    selectedJourneyData = try cacheService.loadJourneyData()
  }

  /// Start trip from deep link (notification handler)
  /// Tries cache first, then falls back to server fetch if needed
  func startFromDeepLink(trainId: String, fromCode: String, toCode: String) async throws {
    logger.info(
      "Starting trip from deep link for trainId: \(trainId), fromCode: \(fromCode), toCode: \(toCode)"
    )

    // Try cache first (most common case - user just created the journey)
    do {
      try await loadSelectedTrainFromCache()

      // Verify cached train matches the trainId from notification
      if let cachedJourneyData = selectedJourneyData,
        cachedJourneyData.trainId == trainId,
        selectedTrain != nil
      {
        logger.info("Using cached train data for trainId: \(trainId)")

        // Ensure stations and routes are loaded
        if stations.isEmpty || routes.isEmpty {
          if (try? loadCachedDataIfAvailable()) == true {
            // Cache loaded successfully, check if we still need data
          }
          // If still empty, we need to load from server
          if stations.isEmpty || routes.isEmpty {
            if let lastUpdatedAt = lastUpdatedAt {
              try await loadData(at: lastUpdatedAt)
            } else {
              // Fallback: try to get lastUpdatedAt from server
              let timestamp: String = try await convexClient.query(
                to: "gapeka:getLastUpdatedAt", yielding: String.self
              )
              try await loadData(at: timestamp)
            }
          }
        }

        // Use cached train directly - it was already projected when the journey was created
        // and remains valid. Re-projecting risks station ID lookup failures.
        guard let cachedTrain = selectedTrain else {
          throw TrainMapError.dataMappingFailed("Cached train data is missing")
        }

        // Live updates will work via liveTrainPosition computed property
        startProjectionUpdates()

        // Execute Live Activity start (by now it should be <= 10 minutes until departure)
        try await executeLiveActivityStart(train: cachedTrain, journeyData: cachedJourneyData)

        // Track journey start using cached train data
        if let from = cachedTrain.fromStation, let to = cachedTrain.toStation {
          AnalyticsEventService.shared.trackJourneyStarted(
            trainId: cachedJourneyData.trainId,
            trainName: cachedTrain.name,
            from: from,
            to: to,
            userSelectedDeparture: cachedJourneyData.userSelectedDepartureTime,
            userSelectedArrival: cachedJourneyData.userSelectedArrivalTime,
            hasAlarmEnabled: AlarmPreferences.shared.defaultAlarmEnabled
          )
        }

        return
      } else {
        logger.info("Cached train doesn't match trainId, fetching from server")
      }
    } catch {
      logger.info(
        "Cache miss or error loading cache: \(error.localizedDescription), fetching from server")
    }

    // Cache miss or doesn't match - fetch from server
    logger.info("Fetching train data from server for trainId: \(trainId)")

    // Ensure stations and routes are loaded
    if stations.isEmpty || routes.isEmpty {
      if let lastUpdatedAt = lastUpdatedAt {
        try await loadData(at: lastUpdatedAt)
      } else {
        let timestamp: String = try await convexClient.query(
          to: "gapeka:getLastUpdatedAt", yielding: String.self
        )
        try await loadData(at: timestamp)
      }
    }

    // Fetch journey segments
    let journeyService = JourneyService()
    let segments = try await journeyService.fetchSegmentsForTrain(trainId: trainId)

    guard !segments.isEmpty else {
      throw TrainMapError.dataMappingFailed("No journey segments found for trainId: \(trainId)")
    }

    // Build journey segments and collect stations
    // Use code-based lookup as primary method for station identification
    let stationsByCode = Dictionary(uniqueKeysWithValues: stations.map { ($0.code, $0) })
    let stationsById = Dictionary(uniqueKeysWithValues: stations.map { ($0.id ?? $0.code, $0) })

    // Find stations using code-based lookup (from deep link parameters)
    guard let fromStation = stationsByCode[fromCode],
      let toStation = stationsByCode[toCode]
    else {
      throw TrainMapError.dataMappingFailed(
        "Could not find stations for journey using codes: fromCode=\(fromCode), toCode=\(toCode)")
    }

    // Create a mapping from segment station IDs to Station objects
    // This handles cases where server station IDs don't match cached station IDs
    var segmentIdToStation: [String: Station] = [:]

    // Map known stations from deep link
    if let firstSegment = segments.first {
      segmentIdToStation[firstSegment.stationId] = fromStation
    }
    if let lastSegment = segments.last {
      segmentIdToStation[lastSegment.stationId] = toStation
    }

    // For other segments, try to find stations by ID or code
    for segment in segments {
      if segmentIdToStation[segment.stationId] == nil {
        // Try ID lookup first
        if let station = stationsById[segment.stationId] {
          segmentIdToStation[segment.stationId] = station
        } else {
          // Try to find by matching code in station data
          // Note: We don't have codes for intermediate stations, so we'll use ID matching
          // If ID doesn't match, we'll need to rely on the segment having the correct ID
          // For now, skip stations we can't match - they'll be handled in projection
        }
      }
    }

    var journeySegments: [JourneySegment] = []
    var allStationsInJourney: [Station] = []

    for (index, segment) in segments.enumerated() {
      if index < segments.count - 1 {
        let nextSegment = segments[index + 1]
        journeySegments.append(
          JourneySegment(
            fromStationId: segment.stationId,
            toStationId: nextSegment.stationId,
            departure: segment.departure,
            arrival: nextSegment.arrival,
            routeId: nextSegment.routeId
          )
        )
      }

      // Add station if we found it
      if let station = segmentIdToStation[segment.stationId] {
        allStationsInJourney.append(station)
      }
    }

    guard let firstSegment = segments.first else {
      throw TrainMapError.dataMappingFailed("Invalid journey segments")
    }

    // Create a comprehensive stationsById dictionary for projection using multi-strategy approach
    // This ensures robustness when segment IDs use different formats (server IDs vs codes)
    let projectionStationsById: [String: Station] = {
      var combined: [String: Station] = [:]

      // Include segment-specific mappings first (highest priority)
      for (key, station) in segmentIdToStation {
        combined[key] = station
      }

      // Add global station mappings by ID
      for station in stations where station.id != nil {
        combined[station.id!] = station
      }

      // Add global station mappings by code (fallback)
      for station in stations {
        combined[station.code] = station
      }

      return combined
    }()

    // Build TrainJourneyData
    let journeyData = TrainJourneyData(
      trainId: trainId,
      segments: journeySegments,
      allStations: allStationsInJourney,
      userSelectedFromStation: fromStation,
      userSelectedToStation: toStation,
      userSelectedDepartureTime: firstSegment.departure,
      userSelectedArrivalTime: segments.last!.arrival
    )

    // Build ProjectedTrain
    let trainJourney = TrainJourney(
      id: firstSegment.trainCode,
      trainId: trainId,
      code: firstSegment.trainCode,
      name: firstSegment.trainName,
      segments: journeySegments
    )

    let routesById = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })

    // Log station lookup diagnostics for debugging
    logger.debug(
      """
      Server fallback: Projecting train with \(projectionStationsById.count) stations mapped. \
      First segment: \(journeySegments.first?.fromStationId ?? "none") → \
      \(journeySegments.first?.toStationId ?? "none")
      """)

    guard
      let projectedTrain = TrainProjector.projectTrain(
        now: Date(),
        journey: trainJourney,
        stationsById: projectionStationsById,
        routesById: routesById
      )
    else {
      throw TrainMapError.dataMappingFailed("Failed to project train")
    }

    // Set selected train and journey data
    selectedTrain = projectedTrain
    selectedJourneyData = journeyData
    startProjectionUpdates()

    // Execute Live Activity start
    try await executeLiveActivityStart(train: projectedTrain, journeyData: journeyData)

    // Track journey start
    if let from = projectedTrain.fromStation, let to = projectedTrain.toStation {
      AnalyticsEventService.shared.trackJourneyStarted(
        trainId: journeyData.trainId,
        trainName: projectedTrain.name,
        from: from,
        to: to,
        userSelectedDeparture: journeyData.userSelectedDepartureTime,
        userSelectedArrival: journeyData.userSelectedArrivalTime,
        hasAlarmEnabled: AlarmPreferences.shared.defaultAlarmEnabled
      )
    }
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

    // Build comprehensive station lookup with multi-strategy approach
    // This ensures TrainProjector can find all stations referenced by JourneySegment IDs
    var stationsById: [String: Station] = [:]

    // Strategy 1: Map by station.id (primary key)
    for station in stations where station.id != nil {
      stationsById[station.id!] = station
    }

    // Strategy 2: Map by station.code (fallback for code-based lookups)
    for station in stations {
      stationsById[station.code] = station
    }

    // Strategy 3: Include journey-specific stations from TrainJourneyData.allStations
    for station in selectedJourneyData.allStations {
      if let id = station.id {
        stationsById[id] = station
      }
      stationsById[station.code] = station
    }

    let routesById = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })

    // Use trainId from journeyData, not selectedTrain.id (which may be journey ID)
    let trainJourney = TrainJourney(
      id: selectedJourneyData.trainId,
      trainId: selectedJourneyData.trainId,
      code: selectedTrain.code,
      name: selectedTrain.name,
      segments: selectedJourneyData.segments
    )

    // Log station lookup diagnostics for debugging
    logger.debug(
      """
      Projecting train with \(stationsById.count) stations mapped. \
      First segment: \(selectedJourneyData.segments.first?.fromStationId ?? "none") → \
      \(selectedJourneyData.segments.first?.toStationId ?? "none")
      """)

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
