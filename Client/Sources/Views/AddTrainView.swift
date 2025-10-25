//
//  TrainPickerView.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 22/10/25.
//

import SwiftUI

@MainActor
struct AddTrainView: View {
  @State private var viewModel: AddTrainViewModel
  @Environment(\.dismiss) private var dismiss
  
  init(store: TrainMapStore) {
    _viewModel = State(initialValue: AddTrainViewModel(store: store))
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Header
        headerView
        
        // Content based on step
        contentView
      }
      .navigationBarHidden(true)
    }
    .padding(.top)
  }
  
  private var headerView: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Title bar
      HStack {
        VStack(alignment: .leading) {
          Text("Tambah Perjalanan Kereta")
            .font(.title2.weight(.bold))
          
          // Subtitle
          Text(viewModel.stepTitle)
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
        onDateTextSubmit: {
          viewModel.parseAndSelectDate(from: viewModel.searchText)
        }
      )
    }
    .padding()
  }
  
  @ViewBuilder
  private var contentView: some View {
    switch viewModel.currentStep {
    case .departure, .arrival:
      stationListView
    case .date:
      datePickerView
    case .results:
      trainResultsView
    }
  }
  
  private var stationListView: some View {
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
  }
  
  private var datePickerView: some View {
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
      
      Spacer()
    }
    .padding()
  }
  
  private var trainResultsView: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.availableTrains) { train in
          TrainServiceRow(train: train)
          
          Divider()
            .padding(.leading, 16)
        }
      }
    }
  }
}

#Preview {
  let mockStore = TrainMapStore.preview
  
  AddTrainView(store: mockStore)
    .environment(mockStore)
}
