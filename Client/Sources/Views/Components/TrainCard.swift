//
//  TrainSheet.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 25/10/25.
//

import Portal
import SwiftUI

struct TrainCard: View {
  let train: ProjectedTrain
  let journeyData: TrainJourneyData?
  let onDelete: () -> Void
  var compactMode: Bool = false

  @State private var showingDeleteAlert = false

  var body: some View {
    VStack(spacing: 0) {
      // Header with train name and delete button (only shown when not in compact mode)
      if !compactMode {
        ZStack {
          // Centered title
          HStack(spacing: 4) {
            Text(train.name)
              .fontWeight(.bold)
              .foregroundStyle(.primary)
              .portal(id: "trainName", .source)
            Text("(\(train.code))")
              .fontWeight(.bold)
              .foregroundStyle(.sublime)
              .portal(id: "trainCode", .source)

          }
          .frame(maxWidth: .infinity)

          // Delete button aligned to trailing
          HStack {
            Spacer()

            Button(action: {
              showingDeleteAlert = true
            }) {
              Image(systemName: "trash")
                .foregroundStyle(.red)
            }
            .alert("Hapus Tracking Kereta?", isPresented: $showingDeleteAlert) {
              Button("Hapus", role: .destructive) {
                onDelete()
              }
              Button("Batal", role: .cancel) {}
            } message: {
              Text("Kreta akan berhenti melacak \(train.name) (\(train.code))")
            }
          }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.backgroundPrimary)
      }

      // Journey details
      HStack(spacing: 10) {
        // Departure station (use user selection if available)
        VStack(spacing: 4) {
          Text(departureStationCode)
            .font(.title2)
            .bold()

          Text(departureStationName)
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

          Text(formatTime(departureTime))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)

        // Train icon and duration
        VStack(spacing: 8) {
          Image("keretaDark")
            .resizable()
            .scaledToFit()
            .frame(width: 120)

          Text(formattedDuration())
            .font(.caption)
            .foregroundStyle(.blue)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        // Arrival station (use user selection if available)
        VStack(spacing: 4) {
          Text(arrivalStationCode)
            .font(.title2)
            .bold()

          Text(arrivalStationName)
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

          Text(formatTime(arrivalTime))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal)
      .padding(.vertical, 16)
      .if(!compactMode) { view in
        view.background(.backgroundPrimary)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .if(compactMode) { view in
      view.shadow(color: .black.opacity(0.25), radius: 4, y: 4)
    }

  }

  // MARK: - Computed Properties

  /// Use user-selected departure station if available, otherwise use current segment
  private var departureStationCode: String {
    journeyData?.userSelectedFromStation.code ?? train.fromStation?.code ?? "--"
  }

  private var departureStationName: String {
    journeyData?.userSelectedFromStation.name ?? train.fromStation?.name ?? "Unknown"
  }

  private var departureTime: Date? {
    journeyData?.userSelectedDepartureTime ?? train.journeyDeparture
  }

  /// Use user-selected arrival station if available, otherwise use current segment
  private var arrivalStationCode: String {
    journeyData?.userSelectedToStation.code ?? train.toStation?.code ?? "--"
  }

  private var arrivalStationName: String {
    journeyData?.userSelectedToStation.name ?? train.toStation?.name ?? "Unknown"
  }

  private var arrivalTime: Date? {
    journeyData?.userSelectedArrivalTime ?? train.journeyArrival
  }

  // MARK: - Helper Functions

  // Helper function to format duration
  private func formattedDuration() -> String {
    guard let departure = departureTime, let arrival = arrivalTime else {
      return "Waktu tidak tersedia"
    }

    let now = Date()

    // Check if train hasn't departed yet
    // Since times are normalized to today, we can do direct comparison
    if now < departure {
      return "Kereta belum berangkat"
    }

    // Check if train has already arrived
    if now >= arrival {
      return "Sudah Tiba"
    }

    // Calculate time remaining until arrival
    let timeInterval = arrival.timeIntervalSince(now)
    let totalMinutes = Int(timeInterval / 60)

    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 && minutes > 0 {
      return "Tiba Dalam \(hours)Jam \(minutes)Menit"
    } else if hours > 0 {
      return "Tiba Dalam \(hours)Jam"
    } else if minutes > 0 {
      return "Tiba Dalam \(minutes)Menit"
    } else {
      return "Tiba Sebentar Lagi"
    }
  }

  private func formatTime(_ date: Date?) -> String {
    guard let date else { return "--:--" }
    return date.formatted(.dateTime.hour().minute())
  }
}

#Preview {
  let stations = [
    Station(
      code: "GMR",
      name: "Gambir",
      position: Position(latitude: -6.1774, longitude: 106.8306),
      city: "Jakarta Selatan"
    ),
    Station(
      code: "JNG",
      name: "Jatinegara",
      position: Position(latitude: -6.2149, longitude: 106.8707),
      city: "Jakarta Selatan"
    ),
  ]

  let train = ProjectedTrain(
    id: "T1-0",
    code: "T1",
    name: "Sample Express",
    position: Position(latitude: -6.1950, longitude: 106.8500),
    moving: true,
    bearing: 45,
    routeIdentifier: "L1",
    speedKph: 60,
    fromStation: stations[0],
    toStation: stations[1],
    segmentDeparture: Date().addingTimeInterval(-15 * 60),
    segmentArrival: Date().addingTimeInterval(15 * 60),
    progress: 0.5,
    journeyDeparture: Date().addingTimeInterval(-60 * 60),
    journeyArrival: Date().addingTimeInterval(2 * 60 * 60)
  )

  ZStack {
    Color.gray.opacity(0.2)
      .ignoresSafeArea()

    TrainCard(train: train, journeyData: nil, onDelete: {}, compactMode: true)
      .padding()
  }
}
