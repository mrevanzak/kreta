//
//  TrainSheet.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 25/10/25.
//

import SwiftUI

struct TrainCard: View {
  let train: ProjectedTrain
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
        // Departure station
        VStack(spacing: 4) {
          Text(train.fromStation?.code ?? "--")
            .font(.title2)
            .bold()

          Text(train.fromStation?.city ?? "Unknown")
            .font(.caption)

          Text(formatTime(train.journeyDeparture))
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

        // Arrival station
        VStack(spacing: 4) {
          Text(train.toStation?.code ?? "--")
            .font(.title2)
            .bold()

          Text(train.toStation?.city ?? "Unknown")
            .font(.caption)

          Text(formatTime(train.journeyArrival))
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

  // Helper function to format duration
  private func formattedDuration() -> String {
    guard let departure = train.journeyDeparture, let arrival = train.journeyArrival else {
      return "Waktu tidak tersedia"
    }

    let interval = arrival.timeIntervalSince(departure)
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60

    if hours > 0 && minutes > 0 {
      return "Tiba Dalam \(hours)Jam \(minutes)Menit"
    } else if hours > 0 {
      return "Tiba Dalam \(hours)Jam"
    } else {
      return "Tiba Dalam \(minutes)Menit"
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

    TrainCard(train: train, onDelete: {})
      .padding()
  }
}
