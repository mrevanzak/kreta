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

  var availableTrains: [Route] = []

  init(store: TrainMapStore) {
    self.store = store
    self.allStations = store.stations
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

    availableTrains = store.routes
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
