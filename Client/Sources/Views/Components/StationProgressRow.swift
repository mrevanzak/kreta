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
  
  private var currentProgress: Double {
    switch item.state {
    case .completed: return 1.0
    case .current:
      // If progress is nil or 0, show marker at station (not departed yet)
      // Otherwise show actual progress
      if let progress = item.progressToNext, progress > 0 {
        return progress
      } else {
        return 0.0 // Keep marker visible at the station
      }
    case .upcoming: return 0.0
    }
  }
  
  // Whether to show the train marker
  private var shouldShowMarker: Bool {
    // Show marker for current station (even before departure)
    // and only if there's a next station
    return item.state == .current && !isLast
  }
  
  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      // Timeline indicator (dot and lines)
      ZStack(alignment: .top) {
        VStack(spacing: 0) {
          // Station dot
          Circle()
            .fill(dotColor)
            .frame(width: dotSize, height: dotSize)
            .overlay(
              Circle()
                .stroke(dotBorderColor, lineWidth: item.state == .current ? 3 : 2)
            )
          
          // Bottom connecting line with progress
          if !isLast {
            ZStack(alignment: .top) {
              // Background (gray for all)
              Rectangle()
                .fill(Color.grayHighlight)
                .frame(width: 6)
              
              // Progress overlay (green for completed/current)
              if item.state == .completed {
                Rectangle()
                  .fill(.highlight)
                  .frame(width: 6)
              } else if item.state == .current && currentProgress > 0 {
                GeometryReader { geometry in
                  Rectangle()
                    .fill(.highlight)
                    .frame(width: 6, height: geometry.size.height * currentProgress)
                }
              }
            }
            .frame(width: 6)
            .frame(minHeight: 90)
          }
        }
        
        // Train marker following progress (on top of everything)
        if shouldShowMarker {
          GeometryReader { geometry in
            Image(systemName: "tram.fill")
              .font(.system(size: 19, weight: .bold))
              .foregroundStyle(.lessDark)
              .background(
                Circle()
                  .fill(
                    LinearGradient(
                      gradient: Gradient(colors: [
                        Color(hex: "#EAFFBD"), // Light green
                        Color(hex: "#A8EA02")  // Lime green
                      ]),
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )
                  .frame(width: 38, height: 38)
              )
              .offset(
                x: 1.5, // Center horizontally on the line
                y: dotSize + (geometry.size.height * currentProgress) - 23 // Position after dot + progress
              )
              .zIndex(100) // Ensure marker is always on top
          }
          .frame(minHeight: 90)
        }
      }
      .frame(width: dotSize)
      
      // Station information
      HStack {
        VStack (alignment: .leading, spacing: 4) {
          Text(item.station.name)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(textColor)
          
          Text(item.station.code)
            .font(.subheadline)
            .foregroundStyle(textColor)
        }
        
        Spacer()
        
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
      .offset(y: -10)
    }
    .zIndex(item.state == .current ? 10 : 0) // Elevate entire row when current to keep marker on top
  }
  
  // MARK: - Computed Properties
  
  private var dotSize: CGFloat {
    switch item.state {
    case .current: return 25
    case .completed: return 25
    case .upcoming: return 25
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
        isStop: true,
        progressToNext: 1.0
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
        isStop: true,
        progressToNext: 0.6
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
        isStop: true,
        progressToNext: nil
      ),
      isFirst: false,
      isLast: true
    )
  }
  .padding()
  .background(.backgroundPrimary)
}
