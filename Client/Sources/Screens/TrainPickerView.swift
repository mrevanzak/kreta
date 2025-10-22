// //
// //  TrainPickerView.swift
// //  tututut
// //
// //  Created by Gilang Banyu Biru Erassunu on 22/10/25.
// //

// import SwiftUI

// enum SelectionStep {
//     case departure
//     case arrival
//     case date
//     case results
// }

// @MainActor
// class TrainPickerViewModel: ObservableObject {
//     @Published var currentStep: SelectionStep = .departure
//     @Published var searchText: String = ""

//     @Published var selectedDepartureStation: Station?
//     @Published var selectedArrivalStation: Station?
//     @Published var selectedDate: Date?

//     @Published var availableTrains: [TrainService] = []

//     let allStations: [Station] = sampleStations

//     var filteredStations: [Station] {
//         let stations: [Station]

//         switch currentStep {
//         case .departure:
//             stations = allStations
//         case .arrival:
//             stations = allStations.filter { $0.id != selectedDepartureStation?.id }
//         case .date, .results:
//             return []
//         }

//         if searchText.isEmpty {
//             return stations
//         }

//         return stations.filter {
//             $0.name.localizedCaseInsensitiveContains(searchText) ||
//             $0.city.localizedCaseInsensitiveContains(searchText) ||
//             $0.code.localizedCaseInsensitiveContains(searchText)
//         }
//     }

//     var stepTitle: String {
//         switch currentStep {
//         case .departure:
//             return "Pilih Stasiun Keberangkatan"
//         case .arrival:
//             return "Pilih Stasiun Tujuan"
//         case .date:
//             return "Keberangkatan Tujuan"
//         case .results:
//             return "Keberangkatan Tujuan"
//         }
//     }

//     func selectStation(_ station: Station) {
//         switch currentStep {
//         case .departure:
//             selectedDepartureStation = station
//             currentStep = .arrival
//             searchText = ""
//         case .arrival:
//             selectedArrivalStation = station
//             currentStep = .date
//             searchText = ""
//         default:
//             break
//         }
//     }

//     func selectDate(_ date: Date) {
//         selectedDate = date
//         loadTrains()
//         currentStep = .results
//     }

//     func loadTrains() {
//         guard let from = selectedDepartureStation,
//               let to = selectedArrivalStation,
//               let date = selectedDate else {
//             return
//         }

//         availableTrains = sampleTrains(from: from, to: to, on: date)
//     }

//     func reset() {
//         currentStep = .departure
//         selectedDepartureStation = nil
//         selectedArrivalStation = nil
//         selectedDate = nil
//         searchText = ""
//         availableTrains = []
//     }
// }

// // MARK: - Main View

// struct TrainPickerView: View {
//     @StateObject private var viewModel = TrainPickerViewModel()
//     @Environment(\.dismiss) private var dismiss

//     var body: some View {
//         NavigationView {
//             VStack(spacing: 0) {
//                 // Header
//                 headerView

//                 // Content based on step
//                 contentView
//             }
//             .navigationBarHidden(true)
//         }
//     }

//     private var headerView: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             HStack {
//                 Text("Tambah Perjalanan Kereta")
//                     .font(.title2)
//                     .fontWeight(.bold)

//                 Spacer()

//                 Button {
//                     dismiss()
//                 } label: {
//                     Image(systemName: "xmark")
//                         .font(.title3)
//                         .foregroundColor(.primary)
//                 }
//             }

//             Text(viewModel.stepTitle)
//                 .font(.subheadline)
//                 .foregroundColor(.secondary)

//             // Station selector or Date display
//             if viewModel.currentStep == .date || viewModel.currentStep == .results {
//                 HStack(spacing: 12) {
//                     stationBadge(viewModel.selectedDepartureStation)

//                     Image(systemName: "arrow.right")
//                         .foregroundColor(.secondary)

//                     stationBadge(viewModel.selectedArrivalStation)

//                     Spacer()

//                     if viewModel.currentStep == .results {
//                         dateDisplay
//                     }
//                 }
//             } else if viewModel.currentStep == .arrival {
//                 HStack(spacing: 12) {
//                     stationBadge(viewModel.selectedDepartureStation)

//                     Image(systemName: "arrow.right")
//                         .foregroundColor(.secondary)

//                     searchBar
//                 }
//             } else {
//                 searchBar
//             }
//         }
//         .padding()
//         .background(Color(.systemBackground))
//     }

//     private func stationBadge(_ station: Station?) -> some View {
//         Group {
//             if let station = station {
//                 Text(station.code)
//                     .font(.headline)
//                     .foregroundColor(.primary)
//                     .frame(width: 60, height: 44)
//                     .background(Color(.systemGray5))
//                     .cornerRadius(8)
//             }
//         }
//     }

//     private var searchBar: some View {
//         HStack {
//             Image(systemName: "magnifyingglass")
//                 .foregroundColor(.secondary)

//             TextField(viewModel.currentStep == .departure ? "Hari, Tanggal" : "Hari, Tanggal",
//                      text: $viewModel.searchText)
//         }
//         .padding(12)
//         .background(Color(.systemGray6))
//         .cornerRadius(8)
//         .frame(maxWidth: .infinity)
//     }

//     private var dateDisplay: some View {
//         Group {
//             if let date = viewModel.selectedDate {
//                 Text(dateFormatter.string(from: date))
//                     .font(.subheadline)
//                     .foregroundColor(.primary)
//                     .padding(.horizontal, 12)
//                     .padding(.vertical, 8)
//                     .background(Color(.systemGray6))
//                     .cornerRadius(8)
//             }
//         }
//     }

//     @ViewBuilder
//     private var contentView: some View {
//         switch viewModel.currentStep {
//         case .departure, .arrival:
//             stationListView
//         case .date:
//             datePickerView
//         case .results:
//             trainResultsView
//         }
//     }

//     private var stationListView: some View {
//         ScrollView {
//             LazyVStack(spacing: 0) {
//                 ForEach(viewModel.filteredStations) { station in
//                     StationRow(station: station)
//                         .onTapGesture {
//                             viewModel.selectStation(station)
//                         }

//                     Divider()
//                         .padding(.leading, 72)
//                 }
//             }
//         }
//     }

//     private var datePickerView: some View {
//         VStack(spacing: 16) {
//             DateOptionRow(
//                 icon: "calendar.badge.clock",
//                 title: "Hari ini",
//                 subtitle: dateFormatter.string(from: Date())
//             )
//             .onTapGesture {
//                 viewModel.selectDate(Date())
//             }

//             Divider()

//             DateOptionRow(
//                 icon: "calendar",
//                 title: "Besok",
//                 subtitle: dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
//             )
//             .onTapGesture {
//                 viewModel.selectDate(Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
//             }

//             Divider()

//             DateOptionRow(
//                 icon: "calendar.badge.plus",
//                 title: "Pilih berdasarkan hari",
//                 subtitle: ""
//             )

//             Spacer()
//         }
//         .padding()
//     }

//     private var trainResultsView: some View {
//         ScrollView {
//             LazyVStack(spacing: 0) {
//                 ForEach(viewModel.availableTrains) { train in
//                     TrainServiceRow(train: train)

//                     Divider()
//                         .padding(.leading, 16)
//                 }
//             }
//         }
//     }

//     private var dateFormatter: DateFormatter {
//         let formatter = DateFormatter()
//         formatter.locale = Locale(identifier: "id_ID")
//         formatter.dateFormat = "EEEE, d MMMM"
//         return formatter
//     }
// }

// // MARK: - Station Row

// struct StationRow: View {
//     let station: Station

//     var body: some View {
//         HStack(spacing: 16) {
//             ZStack {
//                 Circle()
//                     .fill(Color.green.opacity(0.2))
//                     .frame(width: 56, height: 56)

//                 Text(station.code)
//                     .font(.headline)
//                     .fontWeight(.bold)
//             }

//             VStack(alignment: .leading, spacing: 4) {
//                 Text(station.name)
//                     .font(.headline)

//                 Text(station.city)
//                     .font(.subheadline)
//                     .foregroundColor(.secondary)
//             }

//             Spacer()

//             Image(systemName: "chevron.right")
//                 .foregroundColor(.secondary)
//                 .font(.footnote)
//         }
//         .padding()
//         .contentShape(Rectangle())
//     }
// }

// // MARK: - Date Option Row

// struct DateOptionRow: View {
//     let icon: String
//     let title: String
//     let subtitle: String

//     var body: some View {
//         HStack(spacing: 16) {
//             ZStack {
//                 Circle()
//                     .fill(Color.green.opacity(0.2))
//                     .frame(width: 56, height: 56)

//                 Image(systemName: icon)
//                     .font(.title3)
//                     .foregroundColor(.green)
//             }

//             VStack(alignment: .leading, spacing: 4) {
//                 Text(title)
//                     .font(.headline)

//                 if !subtitle.isEmpty {
//                     Text(subtitle)
//                         .font(.subheadline)
//                         .foregroundColor(.secondary)
//                 }
//             }

//             Spacer()
//         }
//         .contentShape(Rectangle())
//     }
// }

// // MARK: - Train Service Row

// struct TrainServiceRow: View {
//     let train: TrainService

//     var body: some View {
//         HStack(alignment: .top, spacing: 16) {
//             VStack(alignment: .leading, spacing: 8) {
//                 Text(train.name)
//                     .font(.headline)

//                 HStack(spacing: 8) {
//                     HStack(spacing: 4) {
//                         Text(train.departStation.code)
//                             .font(.subheadline)
//                             .fontWeight(.semibold)

//                         Text(train.departTime)
//                             .font(.subheadline)
//                             .foregroundColor(.secondary)
//                     }

//                     Image(systemName: "arrow.right")
//                         .font(.caption)
//                         .foregroundColor(.green)

//                     HStack(spacing: 4) {
//                         Text(train.arriveStation.code)
//                             .font(.subheadline)
//                             .fontWeight(.semibold)

//                         Text(train.arriveTime)
//                             .font(.subheadline)
//                             .foregroundColor(.secondary)
//                     }
//                 }
//             }

//             Spacer()

//             Image(systemName: "chevron.right")
//                 .foregroundColor(.secondary)
//                 .font(.footnote)
//         }
//         .padding()
//     }
// }

// // MARK: - Preview

// struct TrainBookingView_Previews: PreviewProvider {
//     static var previews: some View {
//         TrainPickerView()
//     }
// }
