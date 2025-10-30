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

  @State private var viewModel: ViewModel = ViewModel()

  let onTrainSelected: (ProjectedTrain) -> Void

  var body: some View {
    VStack(spacing: 0) {
      headerView()
      contentView()
    }
    .padding(.top)
    .task {
      viewModel.bootstrap(availableTrains: store.trains, allStations: store.stations)
    }
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
            .font(.largeTitle)
            .foregroundStyle(.gray)
            .symbolRenderingMode(.hierarchical)
        }
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
          .background(.ultraThinMaterial)
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
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.filteredTrains) { train in
          TrainResultRow(train: train)
            .contentShape(Rectangle())
            .onTapGesture {
              // Find the corresponding ProjectedTrain from the store
              if let projectedTrain = store.trains.first(where: { $0.id.starts(with: train.id) }) {
                onTrainSelected(projectedTrain)
              }
            }

          Divider()
            .padding(.leading, 16)
        }
      }
    }
    .overlay {
      if viewModel.isLoadingTrains {
        ProgressView()
          .controlSize(.large)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.ultraThinMaterial)
      } else if viewModel.filteredTrains.isEmpty {
        ContentUnavailableView(
          "Tidak ada kereta tersedia",
          systemImage: "train.side.front.car",
          description: Text("Tidak ada layanan kereta untuk rute ini pada tanggal yang dipilih")
        )
      }
    }
  }
}

// MARK: - Preview

#Preview {
  AddTrainView(onTrainSelected: { _ in })
}
