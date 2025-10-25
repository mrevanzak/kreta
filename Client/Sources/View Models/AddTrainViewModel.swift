//
//  TrainBookingViewModel.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 23/10/25.
//

import Foundation
import Observation

enum SelectionStep {
  case departure
  case arrival
  case date
  case results
}

@MainActor
@Observable
final class AddTrainViewModel {
  let store: TrainMapStore
  var allStations: [Station]

  var currentStep: SelectionStep = .departure
  var searchText: String = ""

  var selectedDepartureStation: Station?
  var selectedArrivalStation: Station?
  var selectedDate: Date?

  var availableTrains: [LiveTrain] = []

  init(store: TrainMapStore) {
    self.store = store
    self.allStations = store.stations
  }
  
  func parseAndSelectDate(from text: String) {
    if let date = parseDateFromText(text) {
      selectDate(date)
    }
  }
  
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
      "sep": 9, "okt": 10, "nov": 11, "des": 12
    ]
    
    // Try to parse "DD Month" format
    let components = cleanText.components(separatedBy: .whitespaces)
    if components.count >= 2,
       let day = Int(components[0]),
       let month = monthNames[components[1]] {
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
       let month = Int(parts[1]) {
      var dateComponents = DateComponents()
      dateComponents.year = currentYear
      dateComponents.month = month
      dateComponents.day = day
      return calendar.date(from: dateComponents)
    }
    
    return nil
  }

  var filteredStations: [Station] {
    let stations: [Station]

    switch currentStep {
    case .departure:
      stations = allStations
    case .arrival:
      stations = allStations.filter { $0.id != selectedDepartureStation?.id }
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

  func selectStation(_ station: Station) {
    switch currentStep {
    case .departure:
      selectedDepartureStation = station
      currentStep = .arrival
      searchText = ""
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
    loadTrains()
    currentStep = .results
  }

  func loadTrains() {
    //    guard let from = selectedDepartureStation,
    //          let to = selectedArrivalStation,
    //          let date = selectedDate else {
    //      return
    //    }
    //
    //    availableTrains = sampleTrains(from: from, to: to, on: date)

    availableTrains = store.trains
  }

  func goBackToDeparture() {
    selectedArrivalStation = nil
    selectedDate = nil
    availableTrains = []
    currentStep = .departure
    searchText = ""
  }
  
  func goBackToArrival() {
    selectedDate = nil
    availableTrains = []
    currentStep = .arrival
    searchText = ""
  }
  
  func reset() {
    currentStep = .departure
    selectedDepartureStation = nil
    selectedArrivalStation = nil
    selectedDate = nil
    searchText = ""
    availableTrains = []
  }
}
