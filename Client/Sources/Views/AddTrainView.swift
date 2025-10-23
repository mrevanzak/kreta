//
//  TrainPickerView.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 22/10/25.
//

import SwiftUI

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
  }
  
  private var headerView: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Tambah Perjalanan Kereta")
          .font(.title2)
          .fontWeight(.bold)
        
        Spacer()
        
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.title3)
            .foregroundColor(.primary)
        }
      }
      
      Text(viewModel.stepTitle)
        .font(.subheadline)
        .foregroundColor(.secondary)
      
      // Station selector or Date display
      if viewModel.currentStep == .date || viewModel.currentStep == .results {
        HStack(spacing: 12) {
          stationBadge(viewModel.selectedDepartureStation)
          
          Image(systemName: "arrow.right")
            .foregroundStyle(.secondary)
          
          stationBadge(viewModel.selectedArrivalStation)
          
          Spacer()
          
          if viewModel.currentStep == .results {
            dateDisplay
          }
        }
      } else if viewModel.currentStep == .arrival {
        HStack(spacing: 12) {
          stationBadge(viewModel.selectedDepartureStation)
          
          Image(systemName: "arrow.right")
            .foregroundStyle(.secondary)
          
          searchBar
        }
      } else {
        searchBar
      }
    }
    .padding()
    .background(Color(.systemBackground))
  }
  
  private func stationBadge(_ station: Station?) -> some View {
    Group {
      if let station {
        Text(station.code)
          .font(.headline)
          .foregroundStyle(.primary)
          .frame(width: 60, height: 44)
          .background(.gray.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }
  
  private var searchBar: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      
      TextField(viewModel.currentStep == .departure ? "Hari, Tanggal" : "Hari, Tanggal",
                text: $viewModel.searchText)
    }
    .padding(12)
    .background(.gray.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .frame(maxWidth: .infinity)
  }
  
  private var dateDisplay: some View {
    Group {
      if let date = viewModel.selectedDate {
        Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
          .font(.subheadline)
          .foregroundStyle(.primary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(.gray.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
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
  let train: TrainLine
  
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
  let mockStore = TrainMapStore(service: TrainMapService(httpClient: .development))
  
  // Build the VM
  let vm = AddTrainViewModel(store: mockStore)
  
  AddTrainView(store: mockStore)
    .environment(mockStore)    // only if your view reads the store from env elsewhere
}
