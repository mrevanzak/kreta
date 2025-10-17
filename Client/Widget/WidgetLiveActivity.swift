//
//  WidgetLiveActivity.swift
//  Widget
//
//  Created by Revanza Kurniawan on 08/10/25.
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct ActivityView: View {
  let context: ActivityViewContext<TrainActivityAttributes>
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text("🚆")
        Text("\(context.attributes.from.name) → \(context.attributes.destination.name)")
          .font(.headline)
      }
      Text("Next: \(context.state.stations.next.name)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      HStack(spacing: 6) {
        Image(systemName: "clock")
        // Relative time remaining until the destination ETA
        // Text(context.state.estimatedArrival, style: .relative)
        //   .font(.title3).monospacedDigit()
      }
    }
    .padding(.vertical, 8)
    .activityBackgroundTint(Color(uiColor: .systemBackground))
    .activitySystemActionForegroundColor(Color.accentColor)
  }
}

struct ActivityFamilyView: View {
  let context: ActivityViewContext<TrainActivityAttributes>
  @Environment(\.activityFamily) var activityFamily

  var body: some View {
    switch activityFamily {
    case .small:
      ActivityView(context: context)
    case .medium:
      ActivityView(context: context)
    @unknown default:
      EmptyView()
    }
  }
}

struct ActivityProgressView: View {
  let context: ActivityViewContext<TrainActivityAttributes>
  var body: some View {
    if let destinationEstimatedArrival = context.attributes.destination.estimatedArrival {
      ProgressView(
        timerInterval: Date()...destinationEstimatedArrival,
        countsDown: false,
        label: { EmptyView() },
        currentValueLabel: {
          Image(systemName: "tram")
            .resizable()
            .scaledToFit()
            .frame(width: 12, height: 12)
            .foregroundColor(.yellow)
        }
      )
      .progressViewStyle(.circular)
      .frame(width: 24, height: 24)
    }
  }
}

struct WidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TrainActivityAttributes.self) { context in
      ActivityFamilyView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded regions
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 4) {
            Text(context.attributes.destination.code).font(.title3).bold()
            Text(context.attributes.destination.name)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .padding(.leading)
        }

        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 4) {
            if let destinationEstimatedArrival = context.attributes.destination.estimatedArrival {
              Text(
                destinationEstimatedArrival,
                format: .biggestUnitRelative(units: 2)
              )
              .font(.title3)
              .bold()
              .minimumScaleFactor(0.1)
              .lineLimit(1)
            }

            //TODO: add logic later
            Text("Terlambat")
              .font(.caption).bold()
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color(.systemRed).opacity(0.2))
              .clipShape(Capsule())
              .foregroundColor(Color(.systemRed))
              .minimumScaleFactor(0.1)
              .lineLimit(1)

          }
          .padding(.trailing)
        }
        DynamicIslandExpandedRegion(.center) {
          //TODO: add logic later
          Text("4 menit menuju GDB")
            .font(.caption).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray2).opacity(0.2))
            .clipShape(Capsule())
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack {
            Image("kereta")
              .resizable()
              .scaledToFit()
            HStack(alignment: .center) {
              VStack(alignment: .leading, spacing: 4) {
                Text(context.state.stations.previous.code).font(.body).bold()
                Text(context.state.stations.previous.name)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .truncationMode(.tail)
              }
              .padding(.leading, 36)
              .containerRelativeFrame(.horizontal) { size, _ in
                size * 0.3
              }

              VStack(alignment: .center, spacing: 4) {
                Text(context.attributes.train.name).font(.body).bold()
                Text("KA\(context.attributes.train.code)").font(.caption).foregroundStyle(
                  .secondary)
              }
              .containerRelativeFrame(.horizontal) { size, _ in
                size * 0.4
              }

              VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.stations.next.code).font(.body).bold()
                Text(context.state.stations.next.name)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .truncationMode(.tail)
              }
              .padding(.trailing, 36)
              .containerRelativeFrame(.horizontal) { size, _ in
                size * 0.3
              }
            }
          }
        }
      } compactLeading: {
        HStack(alignment: .center, spacing: 8) {
          ActivityProgressView(context: context)
          Text(context.attributes.destination.code)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.yellow)
            .clipShape(Capsule())
            .foregroundColor(Color(.systemBackground))
        }

      } compactTrailing: {
        if let destinationEstimatedArrival = context.attributes.destination.estimatedArrival {
          Text(
            destinationEstimatedArrival, format: .biggestUnitRelative(units: 2)
          )
          .foregroundColor(.yellow)
        }
      } minimal: {
        ActivityProgressView(context: context)
      }
      .widgetURL(URL(string: "tututut://train"))
      .keylineTint(Color.red)
    }
    .supplementalActivityFamilies([.small, .medium])
  }
}

func getDate(from time: String) -> Date? {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy/MM/dd HH:mm"
  return formatter.date(from: time) ?? nil
}

extension TrainActivityAttributes {
  fileprivate static var preview: TrainActivityAttributes {
    TrainActivityAttributes(
      with: Train(name: "Jayabaya", code: "91"),
      from: TrainStation(
        name: "Malang", code: "ML",
        estimatedArrival: nil,
        estimatedDeparture: getDate(from: "2025/10/17 13:45"),
      ),
      destination: TrainStation(
        name: "Pasar Senen", code: "PSE",
        estimatedArrival: getDate(from: "2025/10/18 01:58"),
        estimatedDeparture: nil
      )
    )
  }
}

extension TrainActivityAttributes.ContentState {
  fileprivate static var sample1: TrainActivityAttributes.ContentState {
    TrainActivityAttributes.ContentState(
      previousStation: TrainStation(
        name: "Surabayagubeng", code: "SGU",
        estimatedArrival: getDate(from: "2025/10/17 15:39"),
        estimatedDeparture: getDate(from: "2025/10/17 15:43")),
      nextStation: TrainStation(
        name: "Surabaya Pasarturi", code: "SBI",
        estimatedArrival: getDate(from: "2025/10/17 15:55"),
        estimatedDeparture: getDate(from: "2025/10/17 16:07")),
    )
  }
}

#Preview("Train Activity", as: .content, using: TrainActivityAttributes.preview) {
  WidgetLiveActivity()
} contentStates: {
  TrainActivityAttributes.ContentState.sample1
}
