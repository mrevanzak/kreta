//
//  TrainPickerView.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 22/10/25.
//

import SwiftUI

// MARK: - Animated Search Bar Component
struct AnimatedSearchBar: View {
    let step: SelectionStep
    let departureStation: Station?
    let arrivalStation: Station?
    let selectedDate: Date?
    @Binding var searchText: String
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 8) {
            // Departure station badge (always visible after selection)
            if let departure = departureStation {
                stationChip(departure, id: "departure")
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Arrow (visible when departure is selected)
            if departureStation != nil {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Arrival station badge (visible after selection)
            if let arrival = arrivalStation {
                stationChip(arrival, id: "arrival")
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Search field (visible until both stations selected)
            if step == .departure || step == .arrival {
                searchField
                    .matchedGeometryEffect(id: "searchField", in: animation)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
            
            // Date display (visible in results step)
            if step == .results, let date = selectedDate {
                Spacer()
                dateChip(date)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: step)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: departureStation?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: arrivalStation?.id)
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
    }
    
    private func stationChip(_ station: Station, id: String) -> some View {
        Text(station.code)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .matchedGeometryEffect(id: id, in: animation)
    }
    
    private func dateChip(_ date: Date) -> some View {
        Text(date, format: .dateTime.day().month(.abbreviated))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private var placeholder: String {
        switch step {
        case .departure:
            return "Stasiun / Kota"
        case .arrival:
            return "Stasiun Tujuan"
        case .date, .results:
            return ""
        }
    }
}

// MARK: - Main View
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
    .padding(.horizontal)
  }
  
  private var headerView: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Title bar
      HStack {
        Text("Tambah Perjalanan Kereta")
          .font(.title2.weight(.bold))
        
        Spacer()
        
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.tertiary)
            .symbolRenderingMode(.hierarchical)
        }
      }
      
      // Subtitle
      Text(viewModel.stepTitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      
      // Animated search bar
      AnimatedSearchBar(
        step: viewModel.currentStep,
        departureStation: viewModel.selectedDepartureStation,
        arrivalStation: viewModel.selectedArrivalStation,
        selectedDate: viewModel.selectedDate,
        searchText: $viewModel.searchText
      )
    }
    .padding()
    .background(.regularMaterial)
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

// MARK: - Station Row

struct StationRow: View {
  let station: Station
  
  var body: some View {
    HStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(.green.opacity(0.2))
          .frame(width: 56, height: 56)
        
        Text(station.code)
          .font(.headline)
          .fontWeight(.bold)
      }
      
      VStack(alignment: .leading, spacing: 4) {
        Text(station.name)
          .font(.headline)
        
        Text(station.name)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      Image(systemName: "chevron.right")
        .foregroundStyle(.secondary)
        .font(.footnote)
    }
    .padding()
    .contentShape(Rectangle())
  }
}

// MARK: - Date Option Row

struct DateOptionRow: View {
  let icon: String
  let title: String
  let subtitle: String
  
  var body: some View {
    HStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(.green.opacity(0.2))
          .frame(width: 56, height: 56)
        
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(.green)
      }
      
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      
      Spacer()
    }
    .contentShape(Rectangle())
  }
}

// MARK: - Train Service Row

struct TrainServiceRow: View {
  let train: Route
  
  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text(train.name)
          .font(.headline)
        
        HStack(spacing: 8) {
          HStack(spacing: 4) {
            Text(train.name)
              .font(.subheadline)
              .fontWeight(.semibold)
            
            Text(train.name)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          
          Image(systemName: "arrow.right")
            .font(.caption)
            .foregroundStyle(.green)
          
          HStack(spacing: 4) {
            Text(train.name)
              .font(.subheadline)
              .fontWeight(.semibold)
            
            Text(train.name)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }
      
      Spacer()
      
      Image(systemName: "chevron.right")
        .foregroundStyle(.secondary)
        .font(.footnote)
    }
    .padding()
  }
}

#Preview {
  // Build a mock store
  let mockStore = TrainMapStore.preview
  
  // Build the VM
  let vm = AddTrainViewModel(store: mockStore)
  
  AddTrainView(store: mockStore)
    .environment(mockStore)    // only if your view reads the store from env elsewhere
}
