//
//  JourneyProgressView.swift
//  kreta
//
//  Created by AI Assistant
//

import SwiftUI

struct JourneyProgressView: View {
  let train: ProjectedTrain
  let journeyData: TrainJourneyData?
  let onDelete: () -> Void
  
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Train card at the top
        TrainCard(
          train: train,
          journeyData: journeyData,
          onDelete: onDelete
        )
        
        // Journey timeline
        if let journeyData = journeyData {
          VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
              Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                .font(.title3)
                .foregroundStyle(.blue)
              
              Text("Perjalanan Kereta")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
              
              Spacer()
              
              // Total stations count
              Text("\(timelineItems(from: journeyData).count) Stasiun")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            Divider()
              .padding(.horizontal, 20)
            
            // Timeline list
            JourneyTimelineView(items: timelineItems(from: journeyData))
              .padding(.horizontal, 20)
          }
          .padding(.vertical, 16)
          .background(.backgroundPrimary)
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .background(.backgroundSecondary)
  }
  
  // MARK: - Helper Methods
  
  private func timelineItems(from journeyData: TrainJourneyData) -> [StationTimelineItem] {
    // Get current segment's from station to determine progress
    let currentSegmentFromStationId = train.fromStation?.id ?? train.fromStation?.code
    
    return StationTimelineItem.buildTimeline(
      from: journeyData,
      currentSegmentFromStationId: currentSegmentFromStationId
    )
  }
}

// MARK: - Preview

#Preview {
  let stations = [
    Station(
      code: "GMR",
      name: "Gambir",
      position: Position(latitude: -6.1774, longitude: 106.8306),
      city: "Jakarta Pusat"
    ),
    Station(
      code: "JNG",
      name: "Jatinegara",
      position: Position(latitude: -6.2149, longitude: 106.8707),
      city: "Jakarta Timur"
    ),
    Station(
      code: "CKR",
      name: "Cikampek",
      position: Position(latitude: -6.4197, longitude: 107.4561),
      city: "Karawang"
    ),
    Station(
      code: "BD",
      name: "Bandung",
      position: Position(latitude: -6.9147, longitude: 107.6098),
      city: "Bandung"
    ),
  ]
  
  let segments = [
    JourneySegment(
      fromStationId: "GMR",
      toStationId: "JNG",
      departure: Date().addingTimeInterval(-3600),
      arrival: Date().addingTimeInterval(-1800),
      routeId: "r1"
    ),
    JourneySegment(
      fromStationId: "JNG",
      toStationId: "CKR",
      departure: Date().addingTimeInterval(-1680),
      arrival: Date().addingTimeInterval(300),
      routeId: "r2"
    ),
    JourneySegment(
      fromStationId: "CKR",
      toStationId: "BD",
      departure: Date().addingTimeInterval(420),
      arrival: Date().addingTimeInterval(3600),
      routeId: "r3"
    ),
  ]
  
  let journeyData = TrainJourneyData(
    trainId: "T1",
    segments: segments,
    allStations: stations,
    userSelectedFromStation: stations[0],
    userSelectedToStation: stations[3],
    userSelectedDepartureTime: Date().addingTimeInterval(-3600),
    userSelectedArrivalTime: Date().addingTimeInterval(3600)
  )
  
  let train = ProjectedTrain(
    id: "T1-0",
    code: "T1",
    name: "Argo Parahyangan",
    position: Position(latitude: -6.2149, longitude: 106.8707),
    moving: true,
    bearing: 45,
    routeIdentifier: "r2",
    speedKph: 80,
    fromStation: stations[1],
    toStation: stations[2],
    segmentDeparture: Date().addingTimeInterval(-1680),
    segmentArrival: Date().addingTimeInterval(300),
    progress: 0.6,
    journeyDeparture: Date().addingTimeInterval(-3600),
    journeyArrival: Date().addingTimeInterval(3600)
  )
  
  JourneyProgressView(
    train: train,
    journeyData: journeyData,
    onDelete: {}
  )
}
