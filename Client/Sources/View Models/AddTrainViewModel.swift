//
//  AddTrainViewModel.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 23/10/25.
//

import Foundation
import Observation

// MARK: - Selection Step

enum SelectionStep {
  case departure
  case arrival
  case date
  case results
}

// MARK: - Journey Data

struct TrainJourneyData: Codable, Equatable {
  let trainId: String
  let segments: [JourneySegment]
  let allStations: [Station]

  // User-selected journey leg (subset of full route)
  let userSelectedFromStation: Station
  let userSelectedToStation: Station
  let userSelectedDepartureTime: Date
  let userSelectedArrivalTime: Date
}

// MARK: - AddTrainView Extension

extension AddTrainView {
  @MainActor
  @Observable
  final class ViewModel {
    // MARK: - Properties

    var allStations: [Station] = []
    var connectedStations: [Station] = []
    var availableTrains: [JourneyService.AvailableTrainItem] = []
    var filteredTrains: [JourneyService.AvailableTrainItem] = []

    // Store journey data separately from ProjectedTrain
    var trainJourneyData: [String: TrainJourneyData] = [:]

    var currentStep: SelectionStep = .departure
    var searchText: String = ""
    var showCalendar: Bool = false
    var isLoadingConnections: Bool = false
    var isLoadingTrains: Bool = false

    var selectedDepartureStation: Station?
    var selectedArrivalStation: Station?
    var selectedDate: Date?

    // MARK: - Private Properties

    private let stationConnectionService = StationConnectionService()
    private let trainConnectionService = TrainConnectionService()
    private let journeyService = JourneyService()

    // no longer caching all journeys; server provides list DTOs

    // MARK: - Public Methods

    func bootstrap(allStations: [Station]) {
      self.allStations = allStations
    }

    /// Fetch connected stations for the selected departure station
    func fetchConnectedStations() async {
      guard let departureId = selectedDepartureStation?.id else {
        connectedStations = []
        return
      }

      isLoadingConnections = true
      defer { isLoadingConnections = false }

      do {
        connectedStations = try await stationConnectionService.fetchConnectedStations(
          departureStationId: departureId
        )
      } catch {
        print("Failed to fetch connected stations: \(error)")
        connectedStations = []
      }
    }

    /// Fetch trains that connect the selected departure and arrival stations
    func fetchAvailableTrains() async {
      guard let departureId = selectedDepartureStation?.id,
        let arrivalId = selectedArrivalStation?.id
      else {
        filteredTrains = []
        return
      }

      isLoadingTrains = true
      defer { isLoadingTrains = false }

      do {
        let items = try await journeyService.fetchProjectedForRoute(
          departureStationId: departureId,
          arrivalStationId: arrivalId
        )
        filteredTrains = items
      } catch {
        print("Failed to fetch available trains: \(error)")
        filteredTrains = []
      }
    }

    /// Build and select a ProjectedTrain from a selected list item
    func didSelect(_ item: JourneyService.AvailableTrainItem) async -> ProjectedTrain {
      let stationsById = Dictionary(
        uniqueKeysWithValues: allStations.map { ($0.id ?? $0.code, $0) })
      let fromStation = stationsById[item.fromStationId]
      let toStation = stationsById[item.toStationId]

      // Fetch journey segments for the complete route
      var journeySegments: [JourneySegment] = []
      var allStationsInJourney: [Station] = []

      do {
        let segments = try await journeyService.fetchSegmentsForTrain(trainId: item.trainId)

        // Convert to JourneySegment model
        for (index, segment) in segments.enumerated() {
          if index < segments.count - 1 {
            let nextSegment = segments[index + 1]

            // Use nextSegment.routeId because the route connects TO the next station
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

          // Collect all stations
          if let station = stationsById[segment.stationId] {
            allStationsInJourney.append(station)
          }
        }

        // Store journey data separately
        trainJourneyData[item.trainId] = TrainJourneyData(
          trainId: item.trainId,
          segments: journeySegments,
          allStations: allStationsInJourney,
          userSelectedFromStation: fromStation!,
          userSelectedToStation: toStation!,
          userSelectedDepartureTime: item.segmentDeparture,
          userSelectedArrivalTime: item.segmentArrival,
        )
      } catch {
        print("Failed to fetch journey segments: \(error)")
      }

      let projected = ProjectedTrain(
        id: item.id,
        code: item.code,
        name: item.name,
        position: Position(
          latitude: fromStation?.position.latitude ?? 0,
          longitude: fromStation?.position.longitude ?? 0
        ),
        moving: false,
        bearing: nil,
        routeIdentifier: item.routeId,
        speedKph: nil,
        fromStation: fromStation,
        toStation: toStation,
        segmentDeparture: item.segmentDeparture,
        segmentArrival: item.segmentArrival,
        progress: nil,
        journeyDeparture: item.segmentDeparture,
        journeyArrival: item.segmentArrival
      )

      return projected
    }

    func parseAndSelectDate(from text: String) {
      if let date = parseDateFromText(text) {
        selectDate(date)
      }
    }

    func selectStation(_ station: Station) {
      switch currentStep {
      case .departure:
        selectedDepartureStation = station
        currentStep = .arrival
        searchText = ""
        // Fetch connected stations in background
        Task {
          await fetchConnectedStations()
        }
      case .arrival:
        selectedArrivalStation = station
        currentStep = .date
        searchText = ""
      default:
        break
      }
    }

    func selectDate(_ date: Date) {
      selectedDate = date
      showCalendar = false
      currentStep = .results
      // Fetch trains for the selected route
      Task {
        await fetchAvailableTrains()
      }
    }

    func showCalendarView() {
      showCalendar = true
    }

    func hideCalendar() {
      selectedDate = nil
      showCalendar = false
    }

    func goBackToDeparture() {
      selectedDepartureStation = nil
      selectedArrivalStation = nil
      selectedDate = nil
      connectedStations = []
      filteredTrains = []
      showCalendar = false
      currentStep = .departure
      searchText = ""
    }

    func goBackToArrival() {
      selectedArrivalStation = nil
      selectedDate = nil
      filteredTrains = []
      showCalendar = false
      currentStep = .arrival
      searchText = ""
      // Re-fetch connected stations
      Task {
        await fetchConnectedStations()
      }
    }

    func goBackToDate() {
      selectedDate = nil
      filteredTrains = []
      showCalendar = false
      currentStep = .date
      searchText = ""
    }

    func reset() {
      currentStep = .departure
      selectedDepartureStation = nil
      selectedArrivalStation = nil
      selectedDate = nil
      searchText = ""
      connectedStations = []
      filteredTrains = []
      showCalendar = false
    }

    // MARK: - Computed Properties

    var filteredStations: [Station] {
      let stations: [Station]

      switch currentStep {
      case .departure:
        stations = allStations
      case .arrival:
        stations = connectedStations
      case .date, .results:
        return []
      }

      if searchText.isEmpty {
        return stations
      }

      return stations.filter {
        $0.name.localizedCaseInsensitiveContains(searchText)
          || $0.code.localizedCaseInsensitiveContains(searchText)
      }
    }

    var stepTitle: String {
      switch currentStep {
      case .departure:
        return "Pilih Stasiun Keberangkatan"
      case .arrival:
        return "Pilih Stasiun Tujuan"
      case .date:
        return "Keberangkatan Tujuan"
      case .results:
        return "Keberangkatan Tujuan"
      }
    }

    // MARK: - Private Methods

    private func parseDateFromText(_ text: String) -> Date? {
      let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

      // Handle common Indonesian date patterns
      // e.g., "24 oktober", "24/10", "24-10", "24 okt"
      let calendar = Calendar.current
      let currentYear = calendar.component(.year, from: Date())

      // Pattern: "DD Month" or "DD MMM"
      let monthNames = [
        "januari": 1, "februari": 2, "maret": 3, "april": 4,
        "mei": 5, "juni": 6, "juli": 7, "agustus": 8,
        "september": 9, "oktober": 10, "november": 11, "desember": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4,
        "jun": 6, "jul": 7, "agu": 8, "ags": 8,
        "sep": 9, "okt": 10, "nov": 11, "des": 12,
      ]

      // Try to parse "DD Month" format
      let components = cleanText.components(separatedBy: .whitespaces)
      if components.count >= 2,
        let day = Int(components[0]),
        let month = monthNames[components[1]]
      {
        var dateComponents = DateComponents()
        dateComponents.year = currentYear
        dateComponents.month = month
        dateComponents.day = day
        return calendar.date(from: dateComponents)
      }

      // Try DD/MM or DD-MM format
      let separators = CharacterSet(charactersIn: "/-")
      let parts = cleanText.components(separatedBy: separators)
      if parts.count >= 2,
        let day = Int(parts[0]),
        let month = Int(parts[1])
      {
        var dateComponents = DateComponents()
        dateComponents.year = currentYear
        dateComponents.month = month
        dateComponents.day = day
        return calendar.date(from: dateComponents)
      }

      return nil
    }
  }
}
