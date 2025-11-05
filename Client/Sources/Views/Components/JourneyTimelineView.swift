//
//  JourneyTimelineView.swift
//  kreta
//
//  Created by AI Assistant
//

import SwiftUI

struct JourneyTimelineView: View {
  let items: [StationTimelineItem]
  
  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        StationProgressRow(
          item: item,
          isFirst: index == 0,
          isLast: index == items.count - 1
        )
      }
    }
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
  
  let items = [
    StationTimelineItem(
      id: "1",
      station: stations[0],
      arrivalTime: nil,
      departureTime: Date().addingTimeInterval(-3600),
      state: .completed,
      isStop: true
    ),
    StationTimelineItem(
      id: "2",
      station: stations[1],
      arrivalTime: Date().addingTimeInterval(-1800),
      departureTime: Date().addingTimeInterval(-1680),
      state: .completed,
      isStop: true
    ),
    StationTimelineItem(
      id: "3",
      station: stations[2],
      arrivalTime: Date().addingTimeInterval(300),
      departureTime: Date().addingTimeInterval(420),
      state: .current,
      isStop: true
    ),
    StationTimelineItem(
      id: "4",
      station: stations[3],
      arrivalTime: Date().addingTimeInterval(3600),
      departureTime: nil,
      state: .upcoming,
      isStop: true
    ),
  ]
  
  ScrollView {
    JourneyTimelineView(items: items)
      .padding()
  }
  .background(.backgroundPrimary)
}
