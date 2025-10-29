//
//  TrainServiceRow.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 24/10/25.
//

import SwiftUI

struct TrainServiceRow: View {
  let train: ProjectedTrain
  
  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      // Train service details
      VStack(alignment: .leading, spacing: 4) {
        Text(train.name)
          .font(.title3).bold()
        
        // Route information
        HStack(spacing: 8) {
          // Departure station
          HStack(spacing: 4) {
            Text(train.fromStation?.code ?? "--")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            Text(formatTime(train.segmentDeparture ?? train.journeyDeparture))
              .font(.subheadline).bold()
          }
          
          // Direction arrow
          Image(systemName: "arrow.right")
            .font(.subheadline)
            .foregroundStyle(.primary)
          
          // Arrival station
          HStack(spacing: 4) {
            Text(train.toStation?.code ?? "--")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            Text(formatTime(train.segmentArrival ?? train.journeyArrival))
              .font(.subheadline).bold()
          }
        }
      }
      
      Spacer()
      
      // Chevron indicator
      ZStack {
        Circle()
          .glassEffect()
          .frame(width: 44)
        Image(systemName: "checkmark")
      }
    }
    .padding()
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
      city: nil
    ),
    Station(
      code: "JNG",
      name: "Jatinegara",
      position: Position(latitude: -6.2149, longitude: 106.8707),
      city: nil
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
  
  TrainServiceRow(train: train)
}
