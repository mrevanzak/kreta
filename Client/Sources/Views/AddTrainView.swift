//
//  AddTrainView.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 22/10/25.
//

import SwiftUI

struct AddTrainView: View {
  @Environment(TrainMapStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.showToast) private var showToast

  @State private var viewModel: ViewModel = ViewModel()

  var body: some View {
    VStack(spacing: 0) {
      headerView()
      contentView()
    }
    .padding(.top)
    .task {
      viewModel.bootstrap(allStations: store.stations)
    }
    .background(.backgroundPrimary)
  }

  // MARK: - Private Views

  private func headerView() -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        // Back button when calendar is shown (only in date step)
        if viewModel.showCalendar && viewModel.currentStep == .date {
          Button {
            viewModel.hideCalendar()
          } label: {
            Image(systemName: "chevron.left")
              .font(.title3)
              .foregroundStyle(.primary)
          }
        }

        VStack(alignment: .leading) {
          Text("Tambah Perjalanan Kereta")
            .font(.title2.weight(.bold))

          // Subtitle
          Text(viewModel.showCalendar ? "Pilih Tanggal" : viewModel.stepTitle)
            .font(.callout)
            .foregroundStyle(.secondary)

        }

        Spacer()

        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.textSecondary, .primary)
            .font(.largeTitle)
        }
        .foregroundStyle(.backgroundSecondary)
        .glassEffect(.regular.tint(.backgroundSecondary))

      }

      // Animated search bar
      AnimatedSearchBar(
        step: viewModel.currentStep,
        departureStation: viewModel.selectedDepartureStation,
        arrivalStation: viewModel.selectedArrivalStation,
        selectedDate: viewModel.selectedDate,
        searchText: $viewModel.searchText,
        onDepartureChipTap: {
          viewModel.goBackToDeparture()
        },
        onArrivalChipTap: {
          viewModel.goBackToArrival()
        },
        onDateChipTap: {
          viewModel.goBackToDate()
        },
        onDateTextSubmit: {
          viewModel.parseAndSelectDate(from: viewModel.searchText)
        }
      )
    }
    .padding()
  }

  @ViewBuilder
  private func contentView() -> some View {
    switch viewModel.currentStep {
    case .departure, .arrival:
      stationListView()
    case .date:
      if viewModel.showCalendar {
        calendarView()
      } else {
        datePickerView()
      }
    case .results:
      trainResultsView()
    }
  }

  private func stationListView() -> some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.filteredStations) { station in
          StationRow(station: station)
            .onTapGesture {
              viewModel.selectStation(station)
            }

          Divider()
            .padding(.leading, 72)
        }
      }
    }
    .overlay {
      if viewModel.isLoadingConnections {
        ProgressView()
          .controlSize(.large)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.backgroundPrimary)
      } else if viewModel.filteredStations.isEmpty {
        ContentUnavailableView.search(text: viewModel.searchText)
      }
    }
  }

  private func datePickerView() -> some View {
    VStack(spacing: 16) {
      DateOptionRow(
        icon: "calendar.badge.clock",
        title: "Hari ini",
        subtitle: Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
      )
      .onTapGesture {
        viewModel.selectDate(Date())
      }

      Divider()

      DateOptionRow(
        icon: "calendar",
        title: "Besok",
        subtitle: (Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
          .formatted(.dateTime.weekday(.wide).day().month(.wide))
      )
      .onTapGesture {
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
          viewModel.selectDate(tomorrow)
        }
      }

      Divider()

      DateOptionRow(
        icon: "calendar.badge.plus",
        title: "Pilih berdasarkan hari",
        subtitle: ""
      )
      .onTapGesture {
        viewModel.showCalendarView()
      }

      Spacer()
    }
    .padding()
  }

  private func calendarView() -> some View {
    CalendarView(
      selectedDate: Binding(
        get: { viewModel.selectedDate ?? Date() },
        set: { viewModel.selectedDate = $0 }
      ),
      onDateSelected: { date in
        viewModel.selectDate(date)
      }
    )
  }

  private func trainResultsView() -> some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(viewModel.filteredTrains) { item in
            TrainServiceRow(
              item: item,
              isSelected: viewModel.isTrainSelected(item)
            )
            .contentShape(Rectangle())
            .onTapGesture {
              viewModel.toggleTrainSelection(item)
            }

            Divider()
              .padding(.leading, 16)
          }
        }
      }

      // Always show confirmation button
      VStack(spacing: 0) {
        Divider()

        Button {
          guard let selectedItem = viewModel.selectedTrainItem else { return }
          Task {
            let projected = await viewModel.didSelect(selectedItem)
            await handleTrainSelection(projected)
          }
        } label: {
          Text("Track Kereta")
            .font(.headline)
            .foregroundStyle(viewModel.selectedTrainItem != nil ? .lessDark : .sublime)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.selectedTrainItem != nil ? .primaryButton : .inactiveButton)
            .cornerRadius(1000)
        }
        .disabled(viewModel.selectedTrainItem == nil)
        .padding()
      }
      .background(.backgroundPrimary)
    }
    .overlay {
      if viewModel.isLoadingTrains {
        ProgressView()
          .controlSize(.large)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.backgroundPrimary)
      } else if viewModel.filteredTrains.isEmpty {
        ContentUnavailableView(
          "Tidak ada kereta tersedia",
          systemImage: "train.side.front.car",
          description: Text("Tidak ada layanan kereta untuk rute ini pada tanggal yang dipilih")
        )
      }
    }
  }

  private func handleTrainSelection(_ train: ProjectedTrain) async {
    let journeyData = viewModel.trainJourneyData[train.id]
    if let journeyData = journeyData {
      do {
        try await store.selectTrain(train, journeyData: journeyData)
        dismiss()
      } catch {
        showToast("Failed to select train: \(error)")
      }
    }
  }
}

// MARK: - Preview

#Preview("Add Train View") {
  let store = TrainMapStore.preview

  // Add more sample stations for a realistic preview
  store.stations = [
    Station(
      id: "GMR",
      code: "GMR",
      name: "Gambir",
      position: Position(latitude: -6.1774, longitude: 106.8306),
      city: "Jakarta"
    ),
    Station(
      id: "JNG",
      code: "JNG",
      name: "Jatinegara",
      position: Position(latitude: -6.2149, longitude: 106.8707),
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
      id: "SB",
      code: "SB",
      name: "Surabaya Gubeng",
      position: Position(latitude: -7.2655, longitude: 112.7523),
      city: "Surabaya"
    ),
  ]

  return AddTrainView()
    .environment(store)
}
