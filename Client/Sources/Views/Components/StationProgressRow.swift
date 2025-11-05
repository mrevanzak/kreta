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
            .frame(width: 2, height: 20)
        }
        
        // Station dot
        Circle()
          .fill(dotColor)
          .frame(width: dotSize, height: dotSize)
          .overlay(
            Circle()
              .stroke(dotBorderColor, lineWidth: item.state == .current ? 3 : 2)
          )
          .shadow(
            color: item.state == .current ? .blue.opacity(0.3) : .clear,
            radius: 8
          )
        
        // Bottom connecting line
        if !isLast {
          Rectangle()
            .fill(lineColor)
            .frame(width: 2)
            .frame(minHeight: 40)
        }
      }
      .frame(width: 24)
      
      // Station information
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          // Station code
          Text(item.station.code)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(textColor)
          
          // Station name
          Text(item.station.name)
            .font(.body)
            .foregroundStyle(textColor)
            .lineLimit(1)
          
          Spacer(minLength: 0)
          
          // Current indicator
          if item.state == .current {
            Text("Sekarang")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.blue, in: Capsule())
          }
        }
        
        // City name
        Text(item.station.city ?? "-")
          .font(.caption)
          .foregroundStyle(.secondary)
        
        // Timing information
        if let arrivalTime = item.arrivalTime {
          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.caption2)
            Text("Tiba: \(formatTime(arrivalTime))")
              .font(.caption)
          }
          .foregroundStyle(.secondary)
          .padding(.top, 2)
        }
        
        // Stop indicator for non-stop stations
        if !item.isStop {
          HStack(spacing: 4) {
            Image(systemName: "arrow.right")
              .font(.caption2)
            Text("Transit")
              .font(.caption)
          }
          .foregroundStyle(.orange)
          .padding(.top, 2)
        }
      }
      .padding(.vertical, 8)
    }
  }
  
  // MARK: - Computed Properties
  
  private var dotSize: CGFloat {
    switch item.state {
    case .current: return 16
    case .completed: return item.isStop ? 12 : 8
    case .upcoming: return item.isStop ? 12 : 8
    }
  }
  
  private var dotColor: Color {
    switch item.state {
    case .completed: return .blue
    case .current: return .blue
    case .upcoming: return .gray.opacity(0.3)
    }
  }
  
  private var dotBorderColor: Color {
    switch item.state {
    case .completed: return .blue.opacity(0.5)
    case .current: return .blue
    case .upcoming: return .gray.opacity(0.2)
    }
  }
  
  private var lineColor: Color {
    switch item.state {
    case .completed: return .blue
    case .current: return .blue.opacity(0.5)
    case .upcoming: return .gray.opacity(0.3)
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
