import CoreLocation
import Foundation

enum TrainProjector {
  private static let dayInMilliseconds: Double = 86_400_000
  private static let defaultBearingSampleCm: Double = 2_000

  // MARK: - Normalization helpers

  private static func positiveModulo(_ value: Double, modulus: Double) -> Double {
    guard modulus != 0 else { return value }
    let remainder = value.truncatingRemainder(dividingBy: modulus)
    return remainder >= 0 ? remainder : remainder + modulus
  }

  /// Mirrors the React Native implementation: bring `timestamp`, `start`, and `end`
  /// into a comparable window while preserving cycle length.
  static func normalizeTimeWindow(
    timestamp: Double,
    startMs: Double,
    endMs: Double
  ) -> (timeMs: Double, startMs: Double, endMs: Double, cycle: Double) {
    var normalizedStart = startMs
    var normalizedEnd = endMs

    if normalizedEnd < normalizedStart {
      normalizedStart = positiveModulo(normalizedStart, modulus: dayInMilliseconds)
      normalizedEnd = positiveModulo(normalizedEnd, modulus: dayInMilliseconds) + dayInMilliseconds
    }

    let cycles = max(1, ceil(normalizedEnd / dayInMilliseconds))
    let cycle = cycles * dayInMilliseconds
    let timeMs = positiveModulo(timestamp, modulus: cycle)

    return (timeMs, normalizedStart, normalizedEnd, cycle)
  }

  static func isWithin(_ timeMs: Double, startMs: Double, endMs: Double) -> Bool {
    let normalized = normalizeTimeWindow(timestamp: timeMs, startMs: startMs, endMs: endMs)
    return normalized.startMs <= normalized.timeMs && normalized.timeMs <= normalized.endMs
  }

  // MARK: - Geometry helpers

  private static func lerp(
    _ from: CLLocationCoordinate2D,
    _ to: CLLocationCoordinate2D,
    t: Double
  ) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(
      latitude: from.latitude + (to.latitude - from.latitude) * t,
      longitude: from.longitude + (to.longitude - from.longitude) * t
    )
  }

  private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double? {
    if abs(from.latitude - to.latitude) < .ulpOfOne
      && abs(from.longitude - to.longitude) < .ulpOfOne
    {
      return nil
    }

    let lat1 = from.latitude * .pi / 180
    let lon1 = from.longitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let lon2 = to.longitude * .pi / 180

    let y = sin(lon2 - lon1) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)
    var angle = atan2(y, x) * 180 / .pi
    if angle < 0 { angle += 360 }
    return angle
  }

  private static func coordinateOnRoute(distanceCm: Double, route: Route) -> CLLocationCoordinate2D?
  {
    let clamped = max(0, min(distanceCm, route.totalLengthCm))
    return route.coordinateAt(distanceCm: clamped)
  }

  // MARK: - Data helpers

  private static func pickActiveStep(timeMs: Double, steps: [RawGapekaPath]) -> RawGapekaPath? {
    steps.first { step in
      isWithin(timeMs, startMs: step.startMs, endMs: step.departMs)
    }
  }

  private static func route(
    for path: RawGapekaPath,
    routesByIdentifier: [String: Route],
  ) -> Route? {
    guard let routeId = path.routeId else { return nil }
    return routesByIdentifier[String(routeId)]
  }

  private static func resolveJourneyDates(
    startMs: Double,
    endMs: Double,
    nowMs: Double,
    timeMs: Double,
    cycle: Double
  ) -> (departure: Date, arrival: Date) {
    let base = nowMs - timeMs
    let departureMs = base + startMs
    var arrivalMs = base + endMs
    if arrivalMs < departureMs {
      arrivalMs += cycle
    }
    return (
      Date(timeIntervalSince1970: departureMs / 1_000),
      Date(timeIntervalSince1970: arrivalMs / 1_000)
    )
  }

  private static func resolveSegmentDates(
    step: RawGapekaPath,
    nowMs: Double,
    timeMs: Double,
    cycle: Double
  ) -> (start: Date, arrival: Date, departure: Date) {
    let base = nowMs - timeMs
    let startAbs = base + step.startMs
    var arrivalAbs = base + step.arrivMs
    if arrivalAbs < startAbs {
      arrivalAbs += cycle
    }
    var departureAbs = base + step.departMs
    if departureAbs < arrivalAbs {
      departureAbs += cycle
    }

    return (
      Date(timeIntervalSince1970: startAbs / 1_000),
      Date(timeIntervalSince1970: arrivalAbs / 1_000),
      Date(timeIntervalSince1970: departureAbs / 1_000)
    )
  }

  // MARK: - Public projection API

  static func projectTrain(
    now: Date,
    train: RawGapekaTrain,
    stations: [Station],
    routes: [Route]
  ) -> ProjectedTrain? {
    let stationLookup = Dictionary(uniqueKeysWithValues: stations.map { ($0.code, $0) })
    let routeLookupByIdentifier = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })

    return projectTrain(
      now: now,
      train: train,
      stationsByCode: stationLookup,
      routesByIdentifier: routeLookupByIdentifier,
    )
  }

  static func projectTrain(
    now: Date,
    train: RawGapekaTrain,
    stationsByCode: [String: Station],
    routesByIdentifier: [String: Route],
  ) -> ProjectedTrain? {
    let nowMs = now.timeIntervalSince1970 * 1_000
    let journeyWindow = normalizeTimeWindow(
      timestamp: nowMs,
      startMs: train.departMs,
      endMs: train.arrivMs
    )
    let timeMs = journeyWindow.timeMs

    guard let step = pickActiveStep(timeMs: timeMs, steps: train.paths) else {
      return nil
    }

    let segmentDates = resolveSegmentDates(
      step: step,
      nowMs: nowMs,
      timeMs: timeMs,
      cycle: journeyWindow.cycle
    )
    let journeyDates = resolveJourneyDates(
      startMs: journeyWindow.startMs,
      endMs: journeyWindow.endMs,
      nowMs: nowMs,
      timeMs: timeMs,
      cycle: journeyWindow.cycle
    )

    let fromStation = stationsByCode[step.orgStCd]
    let toStation = stationsByCode[step.stCd] ?? fromStation
    let isStopped = isWithin(timeMs, startMs: step.arrivMs, endMs: step.departMs)

    let position: Position
    let moving: Bool
    let resolvedBearing: Double?
    let speedKph: Double?
    let progress: Double?

    if isStopped {
      guard let station = toStation ?? fromStation else {
        return nil
      }
      let coord = station.coordinate
      position = Position(latitude: coord.latitude, longitude: coord.longitude)
      moving = false
      speedKph = nil
      progress = 0

      if let origin = fromStation?.coordinate, let destination = toStation?.coordinate {
        resolvedBearing = bearing(from: origin, to: destination)
      } else {
        resolvedBearing = nil
      }

      return ProjectedTrain(
        id: String(train.trId),
        code: train.trCd,
        name: train.trName,
        position: position,
        moving: moving,
        bearing: resolvedBearing,
        routeIdentifier: nil,
        speedKph: speedKph,
        fromStation: fromStation,
        toStation: toStation,
        segmentDeparture: segmentDates.arrival,
        segmentArrival: segmentDates.departure,
        progress: progress,
        journeyDeparture: journeyDates.departure,
        journeyArrival: journeyDates.arrival
      )
    } else {
      guard
        let route = route(
          for: step,
          routesByIdentifier: routesByIdentifier,
        )
      else {
        // Fallback to straight-line interpolation between stations
        guard let origin = fromStation?.coordinate, let destination = toStation?.coordinate else {
          return nil
        }
        let movementWindow = normalizeTimeWindow(
          timestamp: timeMs,
          startMs: step.startMs,
          endMs: step.arrivMs
        )
        let duration = max(movementWindow.endMs - movementWindow.startMs, 1)
        let elapsed = max(0, movementWindow.timeMs - movementWindow.startMs)
        let clampedProgress = max(0, min(1, elapsed / duration))
        let coordinate = lerp(origin, destination, t: clampedProgress)
        let distanceMeters = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
          .distance(
            from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        let durationSeconds = max(segmentDates.arrival.timeIntervalSince(segmentDates.start), 1)
        let speed = durationSeconds > 0 ? (distanceMeters / 1_000) / (durationSeconds / 3_600) : nil

        position = Position(latitude: coordinate.latitude, longitude: coordinate.longitude)
        moving = true
        progress = clampedProgress
        speedKph = speed
        resolvedBearing = bearing(from: origin, to: destination)

        return ProjectedTrain(
          id: String(train.trId),
          code: train.trCd,
          name: train.trName,
          position: position,
          moving: moving,
          bearing: resolvedBearing,
          routeIdentifier: nil,
          speedKph: speedKph,
          fromStation: fromStation,
          toStation: toStation,
          segmentDeparture: segmentDates.start,
          segmentArrival: segmentDates.arrival,
          progress: progress,
          journeyDeparture: journeyDates.departure,
          journeyArrival: journeyDates.arrival
        )
      }

      let movementWindow = normalizeTimeWindow(
        timestamp: timeMs,
        startMs: step.startMs,
        endMs: step.arrivMs
      )
      let duration = max(movementWindow.endMs - movementWindow.startMs, 1)
      let elapsed = max(0, movementWindow.timeMs - movementWindow.startMs)
      let clampedProgress = max(0, min(1, elapsed / duration))

      let distanceForward = (route.totalLengthCm / duration) * elapsed
      let routedDistance =
        step.invRoute
        ? max(0, route.totalLengthCm - distanceForward)
        : min(route.totalLengthCm, distanceForward)

      guard let coordinate = coordinateOnRoute(distanceCm: routedDistance, route: route) else {
        return nil
      }

      let delta = min(defaultBearingSampleCm, route.totalLengthCm)
      let neighborDistance =
        step.invRoute
        ? max(0, routedDistance - delta)
        : min(route.totalLengthCm, routedDistance + delta)
      let neighborCoordinate = coordinateOnRoute(distanceCm: neighborDistance, route: route)
      let heading = neighborCoordinate.flatMap { bearing(from: coordinate, to: $0) }

      let distanceKm = route.totalLengthCm / 100_000
      let segmentDurationSeconds = max(
        segmentDates.arrival.timeIntervalSince(segmentDates.start), 1)
      let speed = segmentDurationSeconds > 0 ? distanceKm / (segmentDurationSeconds / 3_600) : nil

      position = Position(latitude: coordinate.latitude, longitude: coordinate.longitude)
      moving = true
      progress = clampedProgress
      resolvedBearing = heading
      speedKph = speed

      return ProjectedTrain(
        id: String(train.trId),
        code: train.trCd,
        name: train.trName,
        position: position,
        moving: moving,
        bearing: resolvedBearing,
        routeIdentifier: route.id,
        speedKph: speedKph,
        fromStation: fromStation,
        toStation: toStation,
        segmentDeparture: segmentDates.start,
        segmentArrival: segmentDates.arrival,
        progress: progress,
        journeyDeparture: journeyDates.departure,
        journeyArrival: journeyDates.arrival
      )
    }
  }
}
