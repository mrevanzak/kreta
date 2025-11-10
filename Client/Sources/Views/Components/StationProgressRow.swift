//
//  StationProgressRow.swift
//  kreta
//
//  Created by AI Assistant
//

import SwiftUI

struct StationProgressRow: View {
  let item: StationTimelineItem
  let isFirst: Bool
  let isLast: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      // Timeline indicator (dot and lines)
      VStack(spacing: 0) {
        // Top connecting line
        if !isFirst {
          Rectangle()
            .fill(lineColor)
            .frame(width: 6, height: 20)
        }

        // Station dot
        Circle()
          .fill(dotColor)
          .frame(width: dotSize, height: dotSize)
          .overlay(
            Circle()
              .stroke(dotBorderColor, lineWidth: item.state == .current ? 3 : 2)
          )

        // Bottom connecting line
        if !isLast {
          Rectangle()
            .fill(lineColor)
            .frame(width: 6)
            .frame(minHeight: 40)
        }
      }
      .frame(width: 24)

      // Station information
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          VStack(alignment: .leading) {
            // Station code
            Text(item.station.name)
              .font(.system(.title, design: .rounded, weight: .bold))
              .foregroundStyle(textColor)

            // City name
            Text(item.station.code)
              .font(.subheadline)
              .foregroundStyle(textColor)
          }

          Spacer(minLength: 0)

          // Timing information

          if let arrivalTime = item.arrivalTime {
            Text("\(formatTime(arrivalTime))")
              .font(.subheadline)
              .foregroundStyle(textColor)
          } else if let departureTime = item.departureTime {
            Text("\(formatTime(departureTime))")
              .font(.subheadline)
              .foregroundStyle(textColor)
          }

        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - Computed Properties

  private var dotSize: CGFloat {
    switch item.state {
    case .current: return 27
    case .completed: return 27
    case .upcoming: return 27
    }
  }

  private var dotColor: Color {
    switch item.state {
    case .completed: return .highlight
    case .current: return .highlight
    case .upcoming: return .grayHighlight
    }
  }

  private var dotBorderColor: Color {
    switch item.state {
    case .completed: return .highlight
    case .current: return .highlight
    case .upcoming: return .grayHighlight
    }
  }

  private var lineColor: Color {
    switch item.state {
    case .completed: return .highlight
    case .current: return .highlight
    case .upcoming: return .grayHighlight
    }
  }

  private var textColor: Color {
    switch item.state {
    case .completed, .current: return .primary
    case .upcoming: return .secondary
    }
  }

  private func formatTime(_ date: Date) -> String {
    date.formatted(.dateTime.hour().minute())
  }
}

// MARK: - Preview

#Preview {
  let station = Station(
    code: "GMR",
    name: "Gambir",
    position: Position(latitude: -6.1774, longitude: 106.8306),
    city: "Jakarta Pusat"
  )

  VStack(spacing: 0) {
    StationProgressRow(
      item: StationTimelineItem(
        id: "1",
        station: station,
        arrivalTime: nil,
        departureTime: Date(),
        state: .completed,
        isStop: true
      ),
      isFirst: true,
      isLast: false
    )

    StationProgressRow(
      item: StationTimelineItem(
        id: "2",
        station: Station(
          code: "JNG",
          name: "Jatinegara",
          position: Position(latitude: -6.2149, longitude: 106.8707),
          city: "Jakarta Timur"
        ),
        arrivalTime: Date().addingTimeInterval(1800),
        departureTime: Date().addingTimeInterval(1920),
        state: .current,
        isStop: true
      ),
      isFirst: false,
      isLast: false
    )

    StationProgressRow(
      item: StationTimelineItem(
        id: "3",
        station: Station(
          code: "BD",
          name: "Bandung",
          position: Position(latitude: -6.9147, longitude: 107.6098),
          city: "Bandung"
        ),
        arrivalTime: Date().addingTimeInterval(7200),
        departureTime: nil,
        state: .upcoming,
        isStop: true
      ),
      isFirst: false,
      isLast: true
    )
  }
  .padding()
  .background(.backgroundPrimary)
}
