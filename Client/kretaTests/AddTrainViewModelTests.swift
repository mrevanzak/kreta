//
//  AddTrainViewModelTests.swift
//  kretaTests
//
//  Created by Gilang Banyu Biru Erassunu on 30/10/25.
//

import Foundation
import Testing

@testable import kreta

@MainActor
@Suite("AddTrainViewModel Tests")
struct AddTrainViewModelTests {

  // MARK: - Test Fixtures

  let mockStations = [
    Station(
      id: "GMR",
      code: "GMR",
      name: "Gambir",
      position: Position(latitude: -6.1774, longitude: 106.8306),
      city: "Jakarta"
    ),
    Station(
      id: "BD",
      code: "BD",
      name: "Bandung",
      position: Position(latitude: -6.9175, longitude: 107.6191),
      city: "Bandung"
    ),
    Station(
      id: "YK",
      code: "YK",
      name: "Yogyakarta",
      position: Position(latitude: -7.7956, longitude: 110.3695),
      city: "Yogyakarta"
    ),
    Station(
      id: "SGU",
      code: "SGU",
      name: "Surabaya Gubeng",
      position: Position(latitude: -7.2658, longitude: 112.7521),
      city: "Surabaya"
    ),
  ]

  // Create mock items by decoding from JSON since AvailableTrainItem has custom Decodable
  let mockAvailableTrainItems: [JourneyService.AvailableTrainItem] = {
    let json1: [String: Any] = [
      "id": "T1",
      "trainId": "train-1",
      "code": "ARGO",
      "name": "Argo Bromo Anggrek",
      "fromStationId": "GMR",
      "toStationId": "BD",
      "segmentDeparture": 1_729_872_000_000,
      "segmentArrival": 1_729_879_200_000,
      "routeId": "R1",
      "fromStationName": "Gambir",
      "toStationName": "Bandung",
      "fromStationCode": "GMR",
      "toStationCode": "BD",
      "durationMinutes": 120,
    ]

    let json2: [String: Any] = [
      "id": "T2",
      "trainId": "train-2",
      "code": "GAYA",
      "name": "Gaya Baru Malam Selatan",
      "fromStationId": "YK",
      "toStationId": "SGU",
      "segmentDeparture": 1_729_872_000_000,
      "segmentArrival": 1_729_882_800_000,
      "routeId": "R1",
      "fromStationName": "Yogyakarta",
      "toStationName": "Surabaya Gubeng",
      "fromStationCode": "YK",
      "toStationCode": "SGU",
      "durationMinutes": 180,
    ]

    let decoder = JSONDecoder()
    return [
      try! decoder.decode(
        JourneyService.AvailableTrainItem.self, from: JSONSerialization.data(withJSONObject: json1)),
      try! decoder.decode(
        JourneyService.AvailableTrainItem.self, from: JSONSerialization.data(withJSONObject: json2)),
    ]
  }()

  // MARK: - Initialization Tests

  @Test("ViewModel initializes with correct default state")
  func testInitialState() {
    let viewModel = AddTrainView.ViewModel()

    #expect(viewModel.currentStep == .departure)
    #expect(viewModel.searchText.isEmpty)
    #expect(viewModel.showCalendar == false)
    #expect(viewModel.selectedDepartureStation == nil)
    #expect(viewModel.selectedArrivalStation == nil)
    #expect(viewModel.selectedDate == nil)
    #expect(viewModel.allStations.isEmpty)
    #expect(viewModel.availableTrains.isEmpty)
    #expect(viewModel.connectedStations.isEmpty)
    #expect(viewModel.filteredTrains.isEmpty)
    #expect(viewModel.isLoadingConnections == false)
    #expect(viewModel.isLoadingTrains == false)
  }

  @Test("Bootstrap populates stations")
  func testBootstrap() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.bootstrap(allStations: mockStations)

    #expect(viewModel.allStations.count == mockStations.count)
  }

  // MARK: - Station Selection Flow Tests

  @Test("Selecting departure station advances to arrival step")
  func testSelectDepartureStation() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    let gambir = mockStations[0]
    viewModel.selectStation(gambir)

    #expect(viewModel.selectedDepartureStation?.id == gambir.id)
    #expect(viewModel.currentStep == .arrival)
    #expect(viewModel.searchText.isEmpty)
  }

  @Test("Selecting arrival station advances to date step")
  func testSelectArrivalStation() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // First select departure
    viewModel.selectStation(mockStations[0])

    // Then select arrival
    let bandung = mockStations[1]
    viewModel.selectStation(bandung)

    #expect(viewModel.selectedArrivalStation?.id == bandung.id)
    #expect(viewModel.currentStep == .date)
    #expect(viewModel.searchText.isEmpty)
  }

  @Test("Selecting date advances to results step")
  func testSelectDate() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    let testDate = Date()
    viewModel.selectDate(testDate)

    #expect(viewModel.selectedDate != nil)
    #expect(viewModel.currentStep == .results)
    #expect(viewModel.showCalendar == false)
  }

  @Test("Complete flow from departure to results")
  func testCompleteFlow() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Step 1: Select departure
    #expect(viewModel.currentStep == .departure)
    viewModel.selectStation(mockStations[0])

    // Step 2: Select arrival
    #expect(viewModel.currentStep == .arrival)
    viewModel.selectStation(mockStations[1])

    // Step 3: Select date
    #expect(viewModel.currentStep == .date)
    viewModel.selectDate(Date())

    // Step 4: Verify results
    #expect(viewModel.currentStep == .results)
    #expect(viewModel.selectedDepartureStation != nil)
    #expect(viewModel.selectedArrivalStation != nil)
    #expect(viewModel.selectedDate != nil)
  }

  // MARK: - Station Filtering Tests

  @Test("Filtered stations uses connected stations in arrival step")
  func testFilteredStationsUsesConnectedStations() async {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Manually set connected stations to simulate Convex response
    viewModel.connectedStations = Array(mockStations.suffix(2))

    // Move to arrival step
    viewModel.currentStep = .arrival

    let filtered = viewModel.filteredStations

    // Should only show connected stations
    #expect(filtered.count == 2)
  }

  @Test("Search text filters connected stations by name in arrival step")
  func testSearchByNameInArrivalStep() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Simulate connected stations
    viewModel.connectedStations = [mockStations[1], mockStations[2]]
    viewModel.currentStep = .arrival

    viewModel.searchText = "bandung"
    let filtered = viewModel.filteredStations

    #expect(filtered.count == 1)
    #expect(filtered.first?.name == "Bandung")
  }

  @Test("Search text filters stations by code")
  func testSearchByCode() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    viewModel.searchText = "GMR"
    let filtered = viewModel.filteredStations

    #expect(filtered.count == 1)
    #expect(filtered.first?.code == "GMR")
  }

  @Test("Search is case insensitive")
  func testSearchCaseInsensitive() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    viewModel.searchText = "YOGYAKARTA"
    let filtered = viewModel.filteredStations

    #expect(filtered.count == 1)
    #expect(filtered.first?.name == "Yogyakarta")
  }

  @Test("Empty search returns all stations in departure step")
  func testEmptySearchReturnsAll() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    viewModel.searchText = ""
    let filtered = viewModel.filteredStations

    #expect(filtered.count == mockStations.count)
  }

  @Test("Filtered stations returns empty in date and results steps")
  func testFilteredStationsEmptyInNonStationSteps() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Advance to date step
    viewModel.selectStation(mockStations[0])
    viewModel.selectStation(mockStations[1])

    #expect(viewModel.filteredStations.isEmpty)

    // Advance to results step
    viewModel.selectDate(Date())

    #expect(viewModel.filteredStations.isEmpty)
  }

  // MARK: - Calendar Tests

  @Test("Show calendar view sets flag to true")
  func testShowCalendarView() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.showCalendarView()

    #expect(viewModel.showCalendar == true)
  }

  @Test("Hide calendar clears date and flag")
  func testHideCalendar() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.selectedDate = Date()
    viewModel.showCalendar = true

    viewModel.hideCalendar()

    #expect(viewModel.selectedDate == nil)
    #expect(viewModel.showCalendar == false)
  }

  // MARK: - Navigation Tests

  @Test("Go back to departure resets state correctly")
  func testGoBackToDeparture() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Set up full state
    viewModel.selectStation(mockStations[0])
    viewModel.connectedStations = Array(mockStations.suffix(2))
    viewModel.selectStation(mockStations[1])
    viewModel.selectDate(Date())

    // Go back to departure
    viewModel.goBackToDeparture()

    #expect(viewModel.currentStep == .departure)
    #expect(viewModel.selectedDepartureStation == nil)
    #expect(viewModel.selectedArrivalStation == nil)
    #expect(viewModel.selectedDate == nil)
    #expect(viewModel.connectedStations.isEmpty)
    #expect(viewModel.searchText.isEmpty)
    #expect(viewModel.showCalendar == false)
  }

  @Test("Go back to arrival resets arrival and date")
  func testGoBackToArrival() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Set up state
    viewModel.selectStation(mockStations[0])
    viewModel.connectedStations = Array(mockStations.suffix(2))
    viewModel.selectStation(mockStations[1])
    viewModel.selectDate(Date())

    // Go back to arrival
    viewModel.goBackToArrival()

    #expect(viewModel.currentStep == .arrival)
    #expect(viewModel.selectedDepartureStation != nil)
    #expect(viewModel.selectedArrivalStation == nil)
    #expect(viewModel.selectedDate == nil)
    #expect(viewModel.searchText.isEmpty)
    #expect(viewModel.showCalendar == false)
  }

  @Test("Go back to date resets only date")
  func testGoBackToDate() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Set up state
    viewModel.selectStation(mockStations[0])
    viewModel.selectStation(mockStations[1])
    viewModel.selectDate(Date())

    // Go back to date
    viewModel.goBackToDate()

    #expect(viewModel.currentStep == .date)
    #expect(viewModel.selectedDepartureStation != nil)
    #expect(viewModel.selectedArrivalStation != nil)
    #expect(viewModel.selectedDate == nil)
    #expect(viewModel.searchText.isEmpty)
    #expect(viewModel.showCalendar == false)
  }

  @Test("Reset clears all state")
  func testReset() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Set up full state
    viewModel.selectStation(mockStations[0])
    viewModel.connectedStations = Array(mockStations.suffix(2))
    viewModel.filteredTrains = mockAvailableTrainItems
    viewModel.selectStation(mockStations[1])
    viewModel.selectDate(Date())

    // Reset
    viewModel.reset()

    #expect(viewModel.currentStep == .departure)
    #expect(viewModel.selectedDepartureStation == nil)
    #expect(viewModel.selectedArrivalStation == nil)
    #expect(viewModel.selectedDate == nil)
    #expect(viewModel.connectedStations.isEmpty)
    #expect(viewModel.filteredTrains.isEmpty)
    #expect(viewModel.searchText.isEmpty)
    #expect(viewModel.showCalendar == false)
  }

  // MARK: - Step Title Tests

  @Test("Step title matches current step")
  func testStepTitles() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.currentStep = .departure
    #expect(viewModel.stepTitle == "Pilih Stasiun Keberangkatan")

    viewModel.currentStep = .arrival
    #expect(viewModel.stepTitle == "Pilih Stasiun Tujuan")

    viewModel.currentStep = .date
    #expect(viewModel.stepTitle == "Keberangkatan Tujuan")

    viewModel.currentStep = .results
    #expect(viewModel.stepTitle == "Keberangkatan Tujuan")
  }

  // MARK: - Date Parsing Tests

  @Test("Parse date from DD Month format")
  func testParseDateDDMonth() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.searchText = "24 oktober"
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    let calendar = Calendar.current
    let components = calendar.dateComponents([.day, .month], from: viewModel.selectedDate!)

    #expect(components.day == 24)
    #expect(components.month == 10)
  }

  @Test("Parse date from DD/MM format")
  func testParseDateDDMMSlash() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.searchText = "24/10"
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    let calendar = Calendar.current
    let components = calendar.dateComponents([.day, .month], from: viewModel.selectedDate!)

    #expect(components.day == 24)
    #expect(components.month == 10)
  }

  @Test("Parse date from DD-MM format")
  func testParseDateDDMMDash() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.searchText = "24-10"
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    let calendar = Calendar.current
    let components = calendar.dateComponents([.day, .month], from: viewModel.selectedDate!)

    #expect(components.day == 24)
    #expect(components.month == 10)
  }

  @Test("Parse date with abbreviated month name")
  func testParseDateAbbreviatedMonth() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.searchText = "15 okt"
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    let calendar = Calendar.current
    let components = calendar.dateComponents([.day, .month], from: viewModel.selectedDate!)

    #expect(components.day == 15)
    #expect(components.month == 10)
  }

  @Test("Parse date is case insensitive")
  func testParseDateCaseInsensitive() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.searchText = "24 OKTOBER"
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    #expect(viewModel.selectedDate != nil)
  }

  @Test("Parse date handles whitespace")
  func testParseDateWhitespace() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.searchText = "  24 oktober  "
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    #expect(viewModel.selectedDate != nil)
  }

  @Test("Parse date returns nil for invalid format")
  func testParseDateInvalidFormat() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.searchText = "invalid date"
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    #expect(viewModel.selectedDate == nil)
  }

  @Test("Date parsing advances to results step")
  func testParseDateAdvancesToResults() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Navigate to date step
    viewModel.selectStation(mockStations[0])
    viewModel.selectStation(mockStations[1])

    // Parse and select date
    viewModel.searchText = "24 oktober"
    viewModel.parseAndSelectDate(from: viewModel.searchText)

    #expect(viewModel.currentStep == .results)
    #expect(viewModel.selectedDate != nil)
  }

  // MARK: - Edge Case Tests

  @Test("Selecting station in wrong step has no effect")
  func testSelectStationInWrongStep() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    // Advance to date step
    viewModel.selectStation(mockStations[0])
    viewModel.selectStation(mockStations[1])

    let currentStep = viewModel.currentStep

    // Try to select another station
    viewModel.selectStation(mockStations[2])

    // Should remain in date step
    #expect(viewModel.currentStep == currentStep)
  }

  @Test("Search text clears when advancing steps")
  func testSearchTextClearsOnAdvance() {
    let viewModel = AddTrainView.ViewModel()
    viewModel.bootstrap(allStations: mockStations)

    viewModel.searchText = "test"
    viewModel.selectStation(mockStations[0])

    #expect(viewModel.searchText.isEmpty)

    viewModel.searchText = "test2"
    viewModel.selectStation(mockStations[1])

    #expect(viewModel.searchText.isEmpty)
  }

  @Test("Multiple bootstrap calls update data")
  func testMultipleBootstrap() {
    let viewModel = AddTrainView.ViewModel()

    viewModel.bootstrap(allStations: mockStations)
    #expect(viewModel.allStations.count == mockStations.count)

    let newStations = Array(mockStations.prefix(2))
    viewModel.bootstrap(allStations: newStations)

    #expect(viewModel.allStations.count == 2)
  }
}
