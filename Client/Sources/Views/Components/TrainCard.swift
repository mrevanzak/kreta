//
//  TrainSheet.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 25/10/25.
//

import SwiftUI

struct TrainCard: View {
  let train: ProjectedTrain
  let journeyData: TrainJourneyData?
  let onDelete: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Header with train name and class
      ZStack {
        // Centered title
        HStack(spacing: 4) {
          Text(train.name)
            .fontWeight(.bold)
            .foregroundStyle(.white)

        }
        .frame(maxWidth: .infinity)

        // Delete button aligned to trailing
        HStack {
          Spacer()

          Button(action: {
            onDelete()
          }) {
            Image(systemName: "trash")
              .foregroundStyle(.red)
          }
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 12)
      .background(Color.black)

      // Journey details
      HStack(spacing: 0) {
        // Departure station (use user selection if available)
        VStack(spacing: 4) {
          Text(departureStationCode)
            .font(.title2)
            .bold()

          Text(departureStationCity)
            .font(.caption)

          Text(formatTime(departureTime))
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // Train icon and duration
        VStack(spacing: 8) {
          Image("keretaDark")
            .resizable()
            .scaledToFit()

          Text(formattedDuration())
            .font(.caption)
            .foregroundStyle(.cyan)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        // Arrival station (use user selection if available)
        VStack(spacing: 4) {
          Text(arrivalStationCode)
            .font(.title2)
            .bold()

          Text(arrivalStationCity)
            .font(.caption)

          Text(formatTime(arrivalTime))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(
        Color(red: 0.15, green: 0.15, blue: 0.15)
      )
    }
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
  }

  // MARK: - Computed Properties
  
  /// Use user-selected departure station if available, otherwise use current segment
  private var departureStationCode: String {
    journeyData?.userSelectedFromStation.code ?? train.fromStation?.code ?? "--"
  }
  
  private var departureStationCity: String {
    journeyData?.userSelectedFromStation.city ?? train.fromStation?.city ?? "Unknown"
  }
  
  private var departureTime: Date? {
    journeyData?.userSelectedDepartureTime ?? train.journeyDeparture
  }
  
  /// Use user-selected arrival station if available, otherwise use current segment
  private var arrivalStationCode: String {
    journeyData?.userSelectedToStation.code ?? train.toStation?.code ?? "--"
  }
  
  private var arrivalStationCity: String {
    journeyData?.userSelectedToStation.city ?? train.toStation?.city ?? "Unknown"
  }
  
  private var arrivalTime: Date? {
    journeyData?.userSelectedArrivalTime ?? train.journeyArrival
  }

  // MARK: - Helper Functions

  // Helper function to format duration
  private func formattedDuration() -> String {
    guard let arrival = arrivalTime else {
      return "Waktu tidak tersedia"
    }

    // Format both times as strings
    let arrivalString = arrival.formatted(.dateTime.hour().minute())
    let nowString = Date().formatted(.dateTime.hour().minute())
    
    // Parse time strings to calculate interval
    guard let arrivalComponents = parseTimeString(arrivalString),
          let nowComponents = parseTimeString(nowString) else {
      return "Waktu tidak tersedia"
    }
    
    let arrivalMinutes = arrivalComponents.hour * 60 + arrivalComponents.minute
    let nowMinutes = nowComponents.hour * 60 + nowComponents.minute
    
    // Calculate difference (handle day rollover)
    var intervalMinutes = arrivalMinutes - nowMinutes
    if intervalMinutes < 0 {
      intervalMinutes += 24 * 60 // Add 24 hours if negative (crossed midnight)
    }
    
    // If already arrived (more than 12 hours means it's in the past)
    if intervalMinutes > 12 * 60 {
      return "Sudah Tiba"
    }
    
    let hours = intervalMinutes / 60
    let minutes = intervalMinutes % 60

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
  
  private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
    // Expected format: "HH:mm" or "H:mm"
    let components = timeString.split(separator: ".")
    guard components.count == 2,
          let hour = Int(components[0]),
          let minute = Int(components[1]) else {
      return nil
    }
    return (hour, minute)
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
      city: "Jakarta"
    ),
    Station(
      code: "JNG",
      name: "Jatinegara",
      position: Position(latitude: -6.2149, longitude: 106.8707),
      city: "Jakarta"
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

    TrainCard(train: train, journeyData: nil, onDelete: {})
      .padding()
  }
}
